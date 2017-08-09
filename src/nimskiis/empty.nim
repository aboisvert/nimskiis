import skiis

type EmptySkiis[T] = ref object of Skiis[T]

proc initEmptySkiis*[T](): Skiis[T] =
  let newSkiis = new EmptySkiis[T]
  result = newSkiis

method next*[T](skiis: EmptySkiis[T]): Option[T] =
  result = none(T)

method take*[T](skiis: EmptySkiis[T], n: int): seq[T] =
  result = newSeq[T]()

