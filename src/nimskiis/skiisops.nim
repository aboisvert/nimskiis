import
  blockingqueue,
  blockingqueueskiis,
  counter,
  skiis,
  groupedskiis,
  mapskiis,
  flatmapskiis,
  filterskiis,
  helpers,
  std/threadpool,
  sharedptr

#--- parForeach ---

type
  ParForeachParams[T] = object
    context: SkiisContext
    input: Skiis[T]
    op: proc (t: T): void {.nimcall.}
    executorsCompleted: ptr Counter

proc parForeachExecutor[T](params: ptr ParForeachParams[T]) =
  params.input.foreach(n):
    {.gcsafe.}:
      params.op(n)
  params.executorsCompleted[].inc()

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void {.nimcall.}): void =
  let counter = newCounterPtr(context.parallelism)
  let params = allocShared0T(ParForeachParams[T])
  block initParams:
    params.context = context
    params.input = skiis
    params.op = op
    params.executorsCompleted = counter
  for i in 0 ..< context.parallelism:
    spawn parForeachExecutor(params)
  counter[].await()
  block deinitParams:
    counter[].dispose()
    deallocShared(counter)
    deallocShared(params)

#--- stage: input (Skiis[T]) >> operation (proc) >> output (BlockingQueue[U]) ---

type
  StageParams[INPUT, OUTPUT] = object
    context: SkiisContext
    input: Skiis[INPUT]
    output: ptr BlockingQueue[OUTPUT]
    executorsCompleted: ptr Counter

proc `=destroy`[INPUT, OUTPUT](stage: var StageParams[INPUT, OUTPUT]) =
  #echo "dispose StageParamsObj"
  if not stage.input.isNil:
    `=destroy`(stage.input)
    wasMoved(stage.input)
    `=destroy`(stage.output)
    wasMoved(stage.output)
    `=destroy`(stage.executorsCompleted[])

proc stageExecutor[T; U](
  params: ptr StageParams[T, U],
  op: proc (params: ptr StageParams[T, U]): void
): void =
  op(params)
  let parallelism = params.context.parallelism
  let completed = inc(params.executorsCompleted[])
  # careful: params can't be used anymore, except for last owning thread!
  #echo "completed" & $completed
  if completed >= parallelism:
    #echo "last completed ", cast[int](params.output)
    #echo "last completed ", addressRef(params.output)
    params.output[].close()
    `=destroy`(params[])
    deallocShared(params)


proc spawnStage*[T; U](
  input: Skiis[T],
  context: SkiisContext,
  op: proc (params: ptr StageParams[T, U]): void
): Skiis[U] =
  let params = allocShared0T(StageParams[T, U])
  #echo "spawnStage input ", addressPtr(input.asPtr)
  params.input = input
  params.output = newBlockingQueuePtr[U](context.queue)
  params.executorsCompleted = newCounterPtr(context.parallelism)
  params.context = context

  # spawn executors
  for i in 0 ..< context.parallelism:
    spawn stageExecutor(params, op)


  # TODO: figure out how queue gets dealloc'ated
  result = asSkiis[U](params.output)


#--- parMap ---

proc parMapStage[T; U](
  op: proc (t: T): U {.nimcall.}
): proc (params: ptr StageParams[T, U]): void {.closure.} =
  result = proc (params: ptr StageParams[T, U]): void =
    #echo "parMapStage ", addressPtr(params.input.asPtr)
    params.input.foreach(it):
      let output = op(it)
      params.output[].push(output)

proc parMap*[T; U](
  input: Skiis[T],
  context: SkiisContext,
  op: proc (t: T): U {.nimcall.}
): Skiis[U] =
  spawnStage[T, U](input, context, parMapStage(op))

#--- parFlatMap ---

proc parFlatMapStage[T; U](op: proc (t: T): seq[U]): (proc (params: ptr StageParams[T, U]): void {.closure.}) =
  result = proc (params: ptr StageParams[T, U]): void {.closure.} =
    params.input.foreach(n):
      let output = op(n)
      for o in output:
        params.output[].push(o)

proc parFlatMap*[T; U](input: Skiis[T], context: SkiisContext, op: proc (t: T): seq[U] {.nimcall.}): Skiis[U] =
  spawnStage[T, U](input, context, parFlatMapStage(op))

#--- parFilter ---

proc parFilterStage[T](op: proc (t: T): bool): (proc (params: ptr StageParams[T, T]): void {.closure.}) =
  result = proc (params: ptr StageParams[T, T]): void {.closure.} =
    params.input.foreach(n):
      if op(n):
        params.output[].push(n)

proc parFilter*[T](input: Skiis[T], context: SkiisContext, op: proc (t: T): bool {.nimcall.}): Skiis[T] =
  spawnStage[T, T](input, context, parFilterStage(op))

#--- parReduce ---

proc parReduceStage[T](op: proc (t1, t2: T): T): (proc (params: ptr StageParams[T, T]): void {.closure.}) =
  result = proc (params: ptr StageParams[T, T]): void {.closure.} =
    let n = params.input.next()
    if n.isNone: return
    var current: T = n.get()
    params.input.foreach(n):
      current = op(current, n)
    params.output[].push(current)

# Reduce elements in parallel
proc parReduce*[T](input: Skiis[T], context: SkiisContext, op: proc (t1, t2: T): T {.nimcall, gcsafe.}): T =
  let reducers = spawnStage[T, T](input, context, parReduceStage(op))
  let n = reducers.next()
  if n.isNone: raise newException(Defect, "No data to reduce")
  var current: T = n.get()
  reducers.foreach(n):
    current = op(current, n)
  result = current

# Calculate the sum of elements in parallel
proc parSum*[T](input: Skiis[T], context: SkiisContext): T =
  input.parReduce(context) do (x: int, y: int) -> int:
    x + y

proc map*[T; U](input: Skiis[T], op: proc (t: T): U {.nimcall, gcsafe.}): Skiis[U] =
  initMapSkiis(input, op)

# This is currently marked as `unsafe` due to passing a closure across threads
proc unsafeMap*[T; U](input: Skiis[T], op: proc (t: T): U {.closure.}): Skiis[U] =
  initMapSkiis(input, op)

proc flatMap*[T; U](input: Skiis[T], op: proc (t: T): seq[U] {.nimcall, gcsafe.}): Skiis[U] =
  initFlatMapSkiis[T, U](input, op)

proc unsafeFlatMap*[T; U](input: Skiis[T], op: proc (t: T): seq[U]): Skiis[U] =
  initFlatMapSkiis[T, U](input, op)

proc filter*[T](input: Skiis[T], op: proc (t: T): bool {.nimcall, gcsafe.}): Skiis[T] =
  initFilterSkiis(input, op)

# "Lookahead" forces evaluation of previous computation using provided `parallelism`, `queue` and `batch` parameters.
# This is a convenience function meant to provide a standard name for this recurring idiom.
# It is the equivalent of parMap(identity).
proc lookahead*[T](input: Skiis[T], context: SkiisContext): Skiis[T] =
 input.parMap(context, identity[T])

# Group stream into groups of `n` elements
proc grouped*[T](input: Skiis[T], size: int): Skiis[seq[T]] =
  result = initGroupedSkiis(input, size)

proc listenAux[T](op: proc (t: T): void): proc (t: T): T =
 result = proc (t: T): T =
    try:
      op(t)
      #echo "after op ", t
    except:
      let
        e = getCurrentException()
        #msg = getCurrentExceptionMsg()
      #echo "Skiis.listen() - exception ", repr(e), " with message ", msg
      raise e
    result = t
    #echo "after try ", t

proc listen*[T](input: Skiis[T], f: proc(t: T): void): Skiis[T] =
  unsafeMap[T, T](input, listenAux(f))
