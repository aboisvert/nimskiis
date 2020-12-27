import
  skiis,
  helpers

type
  FilterSkiis[T] = ref object of Skiis[T]
    input: Skiis[T]
    op: proc (t: T): bool

method next*[T](this: FilterSkiis[T]): Option[T] {.locks: "unknown", base.} =
  while true:
    let next = this.input.next()
    if next.isSome and this.op(next.get): return next
    if next.isNone: return none(T)

proc initFilterSkiis*[T](input: Skiis[T], op: proc (t: T): bool {.nimcall.}): Skiis[T] =
  let this = new(FilterSkiis[T])
  this.input = input
  this.op = op
  result = this
