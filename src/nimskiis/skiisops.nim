import
  buffer,
  blockingqueue,
  counter,
  skiis,
  helpers,
  os,
  threadpool

export
  skiis

#--- BlockingQueue wrapper ---

proc asSkiis*[T](queue: BlockingQueue[T]): Skiis[T] =
  new(result, dispose[T])
  result.methods.next = proc(): Option[T] =
    let value = queue.pop()
    when T is ref:
      # deepCopy refs across threads
      deepCopy(result, value)
    else:
      result = value

  # todo: optimize take
  result.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = queue.pop(), n)
  result.methods.dispose = proc(): void = discard # BlockingQueue has is own finalizer

converter asPtr*[T](skiis: Skiis[T]): SkiisPtr[T] =
  skiis[].addr

#--- parForeach ---

type
  ParForeachParamsObj[T] = object
    context: SkiisContext
    input: Skiis[T]
    op: proc (t: T): void
    executorsCompleted: Counter

  ParForeachParams[T] = ptr ParForeachParamsObj[T] # ptr to avoid deep copy

proc parForeachExecutor[T](params: ParForeachParams[T]) {.thread.} =
  params.input.foreach(n):
    params.op(n)
  params.executorsCompleted.inc()

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void): void =
  let counter = newCounter(context.parallelism)
  let params = allocShared0T(ParForeachParamsObj[T])
  block initParams:
    GC_ref(skiis)
    GC_ref(counter)
    params.context = context
    params.input = skiis
    params.op = op
    params.executorsCompleted = counter
  for i in 0 ..< context.parallelism:
    spawn parForeachExecutor(params)
  counter.await()
  block deinitParams:
    GC_unref(skiis)
    GC_unref(counter)
    counter.dispose()
    deallocShared(params)

#--- parMap ---

type
  ParMapParamsObj[T, U] = object
    context: SkiisContext
    input: Skiis[T]
    op: proc (t: T): U
    output: BlockingQueue[U]
    executorsCompleted: Counter

  ParMapParams[T, U] = ptr ParMapParamsObj[T, U] # ptr to avoid deep copy

proc parMapExecutor[T, U](params: ParMapParams[T, U]) {.gcsafe.} =
  params.input.foreach(n):
    let result = params.op(n)
    params.output.push(result)

  let completed = params.executorsCompleted.inc()
  debug("parMapExecutor done pushing; count=" & $completed, params.input)
  if completed >= params.context.parallelism:
    params.output.close()
    GC_unref(params.input)
    GC_unref(params.output)
    GC_unref(params.executorsCompleted)
    deallocShared(params)

proc parMap*[T, U](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): U): Skiis[U] =
  let queue = newBlockingQueue[U](context.queue)
  let executorsCompleted = newCounter(context.parallelism)
  let params = allocShared0T(ParMapParamsObj[T, U])
  GC_ref(skiis)
  GC_ref(queue)
  GC_ref(executorsCompleted)
  params.input = skiis
  params.op = op
  params.output = queue
  params.executorsCompleted = executorsCompleted
  params.context = context

  # spawn the mappers
  for i in 0 ..< context.parallelism:
    spawn parMapExecutor(params)

  # TODO: figure out how queue gets dealloc'ated
  result = asSkiis[U](queue)
