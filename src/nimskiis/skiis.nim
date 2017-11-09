import
  interfaced,
  options,
  locks,
  os

export
  options,
  locks

type
  Skiis*[T] = ref object
    methods*: tuple[
      next: proc(): Option[T],
      take: proc(n: int): seq[T]
    ]

  SkiisContext* = object
    parallelism*: int
    queue*: int
    batch*: int
    lock: Lock

proc next*[T](skiis: Skiis[T]): Option[T] =
  skiis.methods.next()

proc take*[T](skiis: Skiis[T], n: int): seq[T] =
  skiis.methods.take(n)

template lockInitWith*(a: var Lock, body: untyped) =
  initLock(a)
  {.locks: [a].}:
    body

template declareSkiis*(typ: typedesc) =
  proc `=deepCopy`*(skiis: Skiis[typ]): Skiis[typ] =
    #echo "deep copy " & $cast[int](unsafeAddr(skiis.methods))
    result = skiis

type ParForeachParams[T] = object
  skiis: Skiis[T]
  op: proc (t: T): void

proc parForeachExecutor[T](params: ParForeachParams[T]) {.thread.} =
  var n = params.skiis.next()
  while n.isSome:
    params.op(n.get)
    n = params.skiis.next()

proc parForeach*[T](skiis: Skiis[T], context: SkiisContext, op: proc (t: T): void): void =
  var threads: array[0..255, Thread[ParForeachParams[T]]] # can't use seq
  for i in 0 ..< context.parallelism:
    createThread[ParForeachParams[T]](threads[i], parForeachExecutor, ParForeachParams[T](skiis: skiis, op: op))
  joinThreads(threads[0 ..< context.parallelism])

proc genericTake*[T](next: proc (): Option[T], n: int): seq[T] =
  if n <= 0: return newSeq[T]()
  result = newSeqOfCap[T](n)
  var n = n
  var x = next()
  while (x.isSome):
    result.add(x.get)
    dec n
    if n == 0: return
    x = next()
