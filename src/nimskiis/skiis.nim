import
  options,
  locks

export 
  options,
  locks

type
  Skiis*[T] = ref object of RootObj

template lockInitWith*(a: Lock, body: untyped) =
  initLock(a)
  {.locks: [a].}:
    body

method next*[T](skiis: Skiis[T]): Option[T] {.base, locks: "unknown".} =
  quit "Skiis.next must be overridden"

method take*[T](skiis: Skiis[T], n: int): seq[T] {.base.} =
  result = newSeqOfCap[T](n)
  if n <= 0: return newSeq[T]()
  var next = skiis.next()
  var n = n
  while next.isSome:
    result.add(next.get)
    n -= 1
    if n == 0: return result
    else: next = skiis.next()

proc `=deepCopy`(skiis: Skiis[int]): Skiis[int] =
  result = skiis
