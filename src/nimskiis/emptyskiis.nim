import skiis, helpers, sharedptr

type
  EmptySkiis[T] = object of SkiisObj[T]

proc EmptySkiis_destructor[T](this: var EmptySkiis[T]) =
  discard

proc `=destroy`[T](this: var EmptySkiis[T]) =
  EmptySkiis_destructor(this)

proc EmptySkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  result = none(T)

proc EmptySkiis_take[T](this: ptr SkiisObj[T], n: int): seq[T] =
  result = newSeq[T]()

proc initEmptySkiis*[T](): Skiis[T] =
  let this = allocShared0T(EmptySkiis[T])
  this.nextMethod = EmptySkiis_next[T]
  this.takeMethod = EmptySkiis_take[T]
  result = asSharedPtr[T, EmptySkiis[T]](this, EmptySkiis_destructor[T])
