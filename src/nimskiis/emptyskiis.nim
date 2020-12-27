import skiis

type
  EmptySkiis[T] = ref object of Skiis[T]

proc next*[T](this: EmptySkiis[T]): Option[T] =
  result = none(T)

proc EmptySkiis_next[T](this: Skiis[T]): Option[T] =
  result = none(T)

proc take*[T](this: EmptySkiis[T], n: int): seq[T] =
  result = newSeq[T]()

proc initEmptySkiis*[T](): Skiis[T] =
  let this = new(EmptySkiis[T])
  this.nextProc = EmptySkiis_next[T]
  result = this