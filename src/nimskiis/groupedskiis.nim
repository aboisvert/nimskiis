import
  skiis,
  helpers

type
  GroupedSkiis[T] = ref object of Skiis[seq[T]]
    size: int
    input: Skiis[T]

method next*[T](this: GroupedSkiis[T]): Option[seq[T]] =
  let g = this.input.take(this.size)
  if g.len > 0:
    some(g)
  else:
    none(seq[T])

proc initGroupedSkiis*[T](input: Skiis[T], size: int): Skiis[seq[T]] =
  let this = new(GroupedSkiis[T])
  this.size = size
  this.input = input
  result = this
