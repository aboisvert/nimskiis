import
  blockingqueue,
  blockingqueueskiis,
  counter,
  list,
  skiis,
  groupedskiis,
  mapskiis,
  flatmapskiis,
  filterskiis,
  helpers,
  os,
  threadpool

export
  skiis

converter asPtr*[T](skiis: Skiis[T]): ptr Skiis[T] =
  skiis[].addr

#--- parForeach ---

#[
template GC_ref(x): void =
  discard

template GC_unref(x): void =
  discard
]#

type
  ParForeachParamsObj[T] = object
    context: SkiisContext
    input: Skiis[T]
    op: proc (t: T): void {.nimcall.}
    executorsCompleted: Counter

  ParForeachParams[T] = ptr ParForeachParamsObj[T] # ptr to avoid deep copy

proc parForeachExecutor[T](params: ParForeachParams[T]) =
  params.input.foreach(n):
    {.gcsafe.}:
      params.op(n)
  params.executorsCompleted.inc()

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void {.nimcall.}): void =
  let counter = newCounter(context.parallelism)
  let params = allocShared0T(ParForeachParamsObj[T])
  block initParams:
    # GC_ref(skiis)
    # GC_ref(counter)
    params.context = context
    params.input = skiis
    params.op = op
    params.executorsCompleted = counter
  for i in 0 ..< context.parallelism:
    spawn parForeachExecutor(params)
  counter.await()
  block deinitParams:
    # GC_unref(skiis)
    # GC_unref(counter)
    # counter.disposeCounter()
    deallocShared(params)

#--- stage: input (Skiis[T]) >> operation (proc) >> output (BlockingQueue[U]) ---

type
  StageParamsObj[INPUT, OUTPUT] = object
    context: SkiisContext
    input: Skiis[INPUT]
    output: BlockingQueue[OUTPUT]
    executorsCompleted: Counter

  StageParams[INPUT, OUTPUT] = ptr StageParamsObj[INPUT, OUTPUT] # ptr to avoid deep copy

proc stageExecutor[T, U](params: StageParams[T, U], op: proc (params: StageParams[T, U]): void): void {.gcsafe.} =
  op(params)

  let completed = params.executorsCompleted.inc()
  if completed >= params.context.parallelism:
    params.output.close()
    # GC_unref(params.input)
    # GC_unref(params.output)
    # GC_unref(params.executorsCompleted)
    deallocShared(params)

proc spawnStage*[T, U](input: Skiis[T], context: SkiisContext, op: proc (params: StageParams[T, U]): void): Skiis[U] =
  let queue = newBlockingQueue[U](context.queue)
  let executorsCompleted = newCounter(context.parallelism)
  let params = allocShared0T(StageParamsObj[T, U])
  # GC_ref(input)
  # GC_ref(queue)
  # GC_ref(executorsCompleted)
  params.input = input
  params.output = queue
  params.executorsCompleted = executorsCompleted
  params.context = context

  # spawn executors
  for i in 0 ..< context.parallelism:
    spawn stageExecutor(params, op)

  # TODO: figure out how queue gets dealloc'ated
  result = asSkiis[U](queue)

#--- parMap ---

proc parMapStage[T, U](op: proc (t: T): U {.nimcall.}): (proc (params: StageParams[T, U]): void {.closure.}) =
  result = proc (params: StageParams[T, U]): void {.closure.} =
    params.input.foreach(n):
      let output = op(n)
      params.output.push(output)

proc parMap*[T, U](input: Skiis[T], context: SkiisContext, op: proc (t: T): U {.nimcall.}): Skiis[U] =
  let stageOp: proc (params: StageParams[T, U]): void {.closure.} = parMapStage(op)
  spawnStage[T, U](input, context, stageOp)

#--- parFlatMap ---

proc parFlatMapStage[T, U](op: proc (t: T): seq[U]): (proc (params: StageParams[T, U]): void {.closure.}) =
  result = proc (params: StageParams[T, U]): void {.closure.} =
    params.input.foreach(n):
      let output = op(n)
      for o in output:
        params.output.push(o)

proc parFlatMap*[T, U](input: Skiis[T], context: SkiisContext, op: proc (t: T): seq[U] {.nimcall.}): Skiis[U] =
  spawnStage[T, U](input, context, parFlatMapStage(op))

#--- parFilter ---

proc parFilterStage[T](op: proc (t: T): bool): (proc (params: StageParams[T, T]): void {.closure.}) =
  result = proc (params: StageParams[T, T]): void {.closure.} =
    params.input.foreach(n):
      if op(n):
        params.output.push(n)

proc parFilter*[T](input: Skiis[T], context: SkiisContext, op: proc (t: T): bool {.nimcall.}): Skiis[T] =
  spawnStage[T, T](input, context, parFilterStage(op))

#--- parReduce ---

proc parReduceStage[T](op: proc (t1, t2: T): T): (proc (params: StageParams[T, T]): void {.closure.}) =
  result = proc (params: StageParams[T, T]): void {.closure.} =
    let n = params.input.next()
    if n.isNone: return
    var current: T = n.get()
    params.input.foreach(n):
      current = op(current, n)
    params.output.push(current)

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

proc map*[T, U](input: Skiis[T], op: proc (t: T): U {.nimcall, gcsafe.}): Skiis[U] =
  initMapSkiis(input, op)

proc flatMap*[T, U](input: Skiis[T], op: proc (t: T): List[U] {.nimcall, gcsafe.}): Skiis[U] =
  initFlatMapSkiis(input, op)

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

#proc listenAux[T](op: proc (t: T): void {.nimcall.}): proc (t: T): T {.nimcall.} =
#  result = proc (t: T): T {.nimcall.}=
#    try: op(t)
#    except: discard
#    t

#proc listen*[T](input: Skiis[T], op: proc (t: T): void {.nimcall.}): Skiis[T] =
  #input.map(listenAux(op))
