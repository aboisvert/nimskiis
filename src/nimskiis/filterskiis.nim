import skiis

type
  FilterSkiis[T] = ref object of Skiis[T]
    input: Skiis[T]
    op: proc (t: T): bool

proc next*[T](this: FilterSkiis[T]): Option[T] =
  while true:
    let next = this.input.next()
    if next.isSome and this.op(next.get): return next
    if next.isNone: return none(T)

proc FilterSkiis_next[T](this: Skiis[T]): Option[T] =
  let this = cast[FilterSkiis[T]](this)
  this.next()

proc initFilterSkiis*[T](input: Skiis[T], op: proc (t: T): bool {.nimcall.}): Skiis[T] =
  let this = new(FilterSkiis[T])
  this.input = input
  this.nextProc = FilterSkiis_next[T]
  this.op = op
  result = this
