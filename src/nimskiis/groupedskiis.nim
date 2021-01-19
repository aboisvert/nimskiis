import skiis

type
  GroupedSkiis[T] = ref object of Skiis[seq[T]]
    size: int
    input: Skiis[T]

proc next*[T](this: GroupedSkiis[T]): Option[seq[T]] =
  let g = this.input.take(this.size)
  if g.len > 0:
    some(g)
  else:
    none(seq[T])

proc GroupedSkiis_next[T](this: Skiis[seq[T]]): Option[seq[T]] =
  let this = cast[GroupedSkiis[T]](this)
  this.next()

proc initGroupedSkiis*[T](input: Skiis[T], size: int): Skiis[seq[T]] =
  let this = new(GroupedSkiis[T])
  this.nextMethod = GroupedSkiis_next[T]
  this.takeMethod = defaultTake[seq[T]]
  this.size = size
  this.input = input
  result = this
