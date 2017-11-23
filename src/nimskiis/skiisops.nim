import
  buffer,
  bufferskiis,
  skiis

export
  skiis

#--- parForeach ---

type ParForeachParams[T] = object
  skiis: ptr Skiis[T]  # ptr to avoid deep copy
  op: proc (t: T): void

proc parForeachExecutor[T](params: ParForeachParams[T]) {.thread.} =
  params.skiis[].foreach(n):
    params.op(n)

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void): void =
  var threads: array[0..255, Thread[ParForeachParams[T]]] # can't use seq
  for i in 0 ..< context.parallelism:
    createThread[ParForeachParams[T]](threads[i], parForeachExecutor,
      ParForeachParams[T](skiis: unsafeAddr(skiis), op: op))
  joinThreads(threads[0 ..< context.parallelism])

#--- parMap ---

type ParMapParams[T, U] = object
  input: ptr Skiis[T]   # ptr to avoid deep copy
  buffer: ptr Buffer[U] # ptr to avoid deep copy
  op: proc (t: T): U

proc parMapExecutor[T, U](params: ParMapParams[T, U]) {.thread.} =
  let input = params.input
  let op = params.op

  input[].foreach(n):
    let result = op(n)
    params.buffer[].push(result)

proc parMap*[T, U](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): U): (Skiis[U]) =
  var threads: array[0..255, Thread[ParMapParams[T, U]]] # can't use seq
  let (output, buffer) = newBufferSkiis[U]()
  for i in 0 ..< context.parallelism:
    createThread[ParMapParams[T, U]](
      threads[i], parMapExecutor, ParMapParams[T, U](
        input: unsafeAddr(skiis), buffer: unsafeAddr(buffer), op: op))
  joinThreads(threads[0 ..< context.parallelism])
  output

## at the point of discovery that I need to limit the size of Buffer
# this will require signaling, suspending/resuming threads, yay!
