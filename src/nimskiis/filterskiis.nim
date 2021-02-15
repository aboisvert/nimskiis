import skiis, helpers

type
  FilterSkiis[T] = object of SkiisObj[T]
    input: Skiis[T]
    op: proc (t: T): bool

proc FilterSkiis_destructor[T](this: var FilterSkiis[T]) =
  #echo "FilterSkiis_destructor"
  `=destroy`(this.input)

proc `=destroy`*[T](this: var FilterSkiis[T]) =
  FilterSkiis_destructor(this)

proc next*[T](this: ptr FilterSkiis[T]): Option[T] =
  while true:
    let next = this.input.next()
    if next.isSome and this.op(next.get): return next
    if next.isNone: return none(T)

proc FilterSkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  let this = downcast[T, FilterSkiis[T]](this)
  this.next()

proc initFilterSkiis*[T](input: Skiis[T], op: proc (t: T): bool): Skiis[T] =
  let this = allocShared0T(FilterSkiis[T])
  this.input = input
  this.nextMethod = FilterSkiis_next[T]
  this.takeMethod = defaultTake[T]
  this.op = op
  result = asSharedPtr[T, FilterSkiis[T]](this, FilterSkiis_destructor[T])
