import
  buffer,
  blockingqueue,
  skiis,
  helpers,
  os

export
  skiis

#--- BlockingQueue wrapper ---

proc asSkiis*[T](queue: BlockingQueue[T]): Skiis[T] =
  result = new Skiis[T]
  result.methods.next = proc(): Option[T] = queue.pop()
    # todo: optimize take
  result.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = queue.pop(), n)

#--- common types

type
  JoinThreadsObj[T, U, TT] = object
    threads: array[0..255, Thread[TT]]
    parallelism: int
    skiis: ptr SkiisObj[T]
    queue: ptr BlockingQueueObj[U]

  JoinThreads[T, U, TT] = ptr JoinThreadsObj[T, U, TT]

proc joinThreadsExecutor[T, U, TT](params: JoinThreads[T, U, TT]) {.thread.} =
  echo "join threads started"
  let queue = asRef(params.queue)
  let skiis = asRef(params.skiis)
  for t in 0 ..< params.parallelism:
    echo $params.threads[t]
  joinThreads(params.threads[0 ..< params.parallelism])
  echo "join threads all joined!"
  echo "params.queue " & addressRef(queue)
  queue.close()
  GC_unref(queue)
  GC_unref(skiis)
  deallocShared(params)

#--- parForeach ---

type ParForeachParams[T] = object
  skiis: ptr SkiisObj[T]  # ptr to avoid deep copy
  op: proc (t: T): void

proc parForeachExecutor[T](params: ParForeachParams[T]) {.thread.} =
  let skiis = asRef(params.skiis)
  skiis.foreach(n):
    params.op(n)
  GC_unref(skiis)

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void): void =
  var threads: array[0..255, Thread[ParForeachParams[T]]] # can't use seq
  GC_ref(skiis)
  let params = ParForeachParams[T](skiis: skiis[].addr, op: op)
  for i in 0 ..< context.parallelism:
    createThread[ParForeachParams[T]](threads[i], parForeachExecutor, params)
  joinThreads(threads[0 ..< context.parallelism])

#--- parMap ---

type ParMapParams[T, U] = object
  input: ptr SkiisObj[T]   # ptr to avoid deep copy
  queue: ptr BlockingQueueObj[U] # ptr to avoid deep copy
  op: proc (t: T): U

proc parMapExecutor[T, U](params: ParMapParams[T, U]) {.thread.} =
  echo "parMapExecutor started"
  let input = asRef(params.input)
  let op = params.op
  let queue = asRef(params.queue)
  input.foreach(n):
    let result = op(n)
    queue.push(result)
  echo "parMapExecutor done"

proc parMap*[T, U](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): U): (Skiis[U], BlockingQueue[U]) =
  type P = ParMapParams[T, U]
  type J = JoinThreads[T, U, P]
  let queue = newBlockingQueue[U](context.queue)
  GC_ref(queue)
  GC_ref(skiis)
  echo "queue at " & addressRef(queue)

  let joinThreads = allocT(JoinThreadsObj[T, U, P])
  joinThreads.parallelism = context.parallelism
  joinThreads.skiis = skiis[].addr
  joinThreads.queue = queue[].addr

  # spawn the mappers
  for i in 0 ..< context.parallelism:
    createThread[P](
      joinThreads.threads[i], parMapExecutor, ParMapParams[T, U](
        input: skiis[].addr, queue: queue[].addr, op: op))

  echo "after spawn of mappers"

  sleep(2000)

  # spawn the join thread
  var joinThread: Thread[J]
  createThread[J](joinThread, joinThreadsExecutor, joinThreads)
  echo "after create join thread"
  result = (asSkiis[U](queue), queue)
