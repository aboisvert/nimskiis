import skiis

type
  GroupedSkiis[T] = ref object of Skiis[seq[T]]
    size: int
    input: Skiis[T]

method next*[T](this: GroupedSkiis[T]): Option[seq[T]] {.locks: "unknown", base.} =
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
