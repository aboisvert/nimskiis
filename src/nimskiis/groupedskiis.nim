import skiis, helpers

type
  GroupedSkiis[T] = object of SkiisObj[seq[T]]
    size: int
    input: Skiis[T]

proc GroupedSkiis_destructor[T](this: var GroupedSkiis[T]) =
  discard

proc `=destroy`[T](this: var GroupedSkiis[T]) =
  GroupedSkiis_destructor(this)

proc next[T](this: ptr GroupedSkiis[T]): Option[seq[T]] =
  let g = this.input.take(this.size)
  if g.len > 0:
    some(g)
  else:
    none(seq[T])

proc GroupedSkiis_next[T](this: ptr SkiisObj[seq[T]]): Option[seq[T]] =
  let this = downcast[seq[T], GroupedSkiis[T]](this)
  this.next()

proc initGroupedSkiis*[T](input: Skiis[T], size: int): Skiis[seq[T]] =
  let this = allocShared0T(GroupedSkiis[T])
  this.nextMethod = GroupedSkiis_next[T]
  this.takeMethod = defaultTake[seq[T]]
  this.size = size
  this.input = input
  result = asSharedPtr[seq[T], GroupedSkiis[T]](this, GroupedSkiis_destructor[T])
