import
  blockingqueue,
  blockingqueueskiis,
  counter,
  skiis,
  groupedskiis,
  mapskiis,
  envskiis,
  flatmapskiis,
  filterskiis,
  listenskiis,
  helpers,
  std/threadpool,
  sharedptr

#--- parForeach ---

type
  Stage[PREV, FINPUT, FOUTPUT, QUEUE] = object
    context: SkiisContext
    input: Skiis[PREV] # SharedPtr
    output: ptr BlockingQueue[QUEUE] # not owned
    executorsStarted: ptr Counter # owned
    executorsCompleted: ptr Counter # owned
    stageProc: StageProc[PREV, FINPUT, FOUTPUT, QUEUE]
    stageOp: StageOp[FINPUT, FOUTPUT]

  StageOp[T; U] = proc(t: T): U {.nimcall.}

  StageProc[PREV, INPUT, OUTPUT, QUEUE] =
    proc (params: ptr Stage[PREV, INPUT, OUTPUT, QUEUE]): void {.nimcall.}

  ParForeachParams[T] = object
    context: SkiisContext
    input: Skiis[T]
    stageOp: StageOp[T, void]
    executorsCompleted: ptr Counter

proc parForeachExecutor[T](params: ptr ParForeachParams[T]) =
  let op = params.stageOp
  params.input.foreach(n):
    op(n)
  #echo "before finished"
  params.executorsCompleted[].inc()
  #echo "finished ", n

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: StageOp[T, void]): void =
  let counter = newCounterPtr(context.parallelism)
  let params = allocShared0T(ParForeachParams[T])
  block initParams:
    params.context = context
    params.input = skiis
    params.stageOp = op
    params.executorsCompleted = counter
  for i in 0 ..< context.parallelism:
    spawn parForeachExecutor(params)
  counter[].await()
  block deinitParams:
    counter[].dispose()
    deallocShared(counter)
    `=destroy`(params.input) # decrease refcount due to assignment above
    deallocShared(params)

#--- stage: input (Skiis[T]) >> operation (proc) >> output (BlockingQueue[U]) ---

proc dispose[PREV, INPUT, OUTPUT, QUEUE](stage: var Stage[PREV, INPUT, OUTPUT, QUEUE]) =
  #echo "dispose Stage"
  if not stage.input.isNil:
    # Stage does not own stage.{input, output}
    dispose(stage.executorsStarted[])
    dispose(stage.executorsCompleted[])
    deallocShared(stage.executorsStarted)
    deallocShared(stage.executorsCompleted)
    `=destroy`(stage.input)

proc stageExecutor[P; T; U; A](params: ptr Stage[P, T, U, A]): void =
  let parallelism = params.context.parallelism
  when defined(debugStage):
    let started = inc(params.executorsStarted[])
    echo "started " & $started

  try:
    #echo "before op ", $started
    params.stageProc(params)
    #echo "after op ", $started
  except:
    let e = getCurrentException()
    let msg = getCurrentExceptionMsg()
    echo "Skiis.stageExecutor() - exception ", repr(e), " with message ", msg
    raise e

  let completed = inc(params.executorsCompleted[])
  # careful: params can't be used anymore, except for last owning thread!
  when defined(debugStage):
    echo "started ", started, " completed ", completed
  if completed >= parallelism:
    when defined(debugStage):
      echo "last completed input ", params.input
      echo "last completed queue ", addressRef(params.output)
    params.output[].close()
    dispose(params[])
    deallocShared(params)


proc spawnStage*[P; T; U; A](
  input: Skiis[P],
  context: SkiisContext,
  stageProc: StageProc[P, T, U, A],
  stageOp: StageOp[T, U]
): Skiis[A] =
  let params = allocShared0T(Stage[P, T, U, A])
  params.input = input
  params.output = newBlockingQueuePtr[A](context.queue)
  params.executorsStarted = newCounterPtr(context.parallelism)
  params.executorsCompleted = newCounterPtr(context.parallelism)
  params.context = context
  params.stageProc = stageProc
  params.stageOp = stageOp

  result = asSkiis[A](params.output)

  # spawn executors
  for i in 0 ..< context.parallelism:
    spawn stageExecutor(params)

#--- parMap ---

proc parMapStage[T; U](params: ptr Stage[T, T, U, U]): void =
  #echo "parMapStage ", addressPtr(params.input.asPtr)
  let op = params.stageOp
  params.input.foreach(it):
    let output: U = op(it)
    params.output[].push(output)

proc parMap*[T; U](
  input: Skiis[T],
  context: SkiisContext,
  op: StageOp[T, U]
): Skiis[U] =
  spawnStage[T, T, U, U](input, context, parMapStage[T, U], op)

#--- parFlatMap ---

proc parFlatMapStage[T; U](params: ptr Stage[T, T, seq[U], U]): void =
  let op = params.stageOp
  params.input.foreach(n):
    let output = op(n)
    for o in output:
      params.output[].push(o)

proc parFlatMap*[T; U](input: Skiis[T], context: SkiisContext, op: StageOp[T, seq[U]]): Skiis[U] =
  spawnStage[T, T, seq[U], U](input, context, parFlatMapStage[T, U], op)

#--- parFilter ---

proc parFilterStage[T](params: ptr Stage[T, T, bool, T]): void =
  let op = params.stageOp
  params.input.foreach(n):
    #echo "parFilter got ", n
    if op(n):
      params.output[].push(n)

proc parFilter*[T](input: Skiis[T], context: SkiisContext, op: proc (t: T): bool {.nimcall.}): Skiis[T] =
  spawnStage[T, T, bool, T](input, context, parFilterStage[T], op)

#--- parReduce ---

proc parReduceStage[T](params: ptr Stage[T, (T, T), T, T]): void =
  let n: Option[T] = params.input.next()
  if n.isNone: return
  let op: StageOp[(T, T), T] = params.stageOp
  var current: T = n.get()
  params.input.foreach(n):
    current = op((current, n))
  params.output[].push(current)

# Reduce elements in parallel
proc parReduce*[T](input: Skiis[T], context: SkiisContext, op: proc (t: (T, T)): T {.nimcall, gcsafe.}): T =
  let reducers = spawnStage[T, (T, T), T, T](input, context, parReduceStage[T], op)
  let n = reducers.next()
  if n.isNone: raise newException(Defect, "No data to reduce")
  var current: T = n.get()
  reducers.foreach(n):
    current = op((current, n))
  result = current

# Calculate the sum of elements in parallel
proc parSum*[T](input: Skiis[T], context: SkiisContext): T =
  input.parReduce(context) do (t: (int, int)) -> int:
    t[0] + t[1]

proc map*[T; U](input: Skiis[T], op: proc (t: T): U {.nimcall}): Skiis[U] =
  initMapSkiis[T, U](input, op)

proc withEnv*[T; ENV](input: Skiis[T], env: SharedPtr[ENV]): Skiis[ValueEnv[T, ENV]] =
  initEnvSkiis[T, ENV](input, env)

proc removeEnv2*[T; ENV](input: Skiis[(T, ENV)]): Skiis[T] =
  proc remove(t: (T, ENV)): T = t[0]
  input.map(remove)

proc removeEnv*[T; ENV](input: Skiis[ValueEnv[T, ENV]]): Skiis[T] =
  proc remove(t: ValueEnv[T, ENV]): T = t.value
  map(input, remove)

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

proc listen*[T](input: Skiis[T], f: proc(t: T): void {.nimcall, gcsafe.}): Skiis[T] =
  initListenSkiis[T](input, f)
