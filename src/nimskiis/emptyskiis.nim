import skiis

type
  EmptySkiis[T] = ref object of Skiis[T]

method next*[T](this: EmptySkiis[T]): Option[T] {.locks: "unknown".} =
  result = none(T)

method take*[T](this: EmptySkiis[T], n: int): seq[T] {.locks: "unknown".} =
  result = newSeq[T]()

proc initEmptySkiis*[T](): Skiis[T] =
  let this = new(EmptySkiis[T])
  result = this
