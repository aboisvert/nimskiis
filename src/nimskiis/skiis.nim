import
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

template foreach*[T](skiis: Skiis[T], name, body: untyped) =  
  var next = skiis.next()
  while (next.isSome):
    let name = next.get
    body
    next = skiis.next()

proc toSeq*[T](skiis: Skiis[T]): seq[T] =
  result = newSeq[T]()
  skiis.foreach(n):
    result.add(n)