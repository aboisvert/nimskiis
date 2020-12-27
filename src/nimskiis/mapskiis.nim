import skiis

type
  MapSkiis[T, U] = ref object of Skiis[U]
    input: Skiis[T]
    op: proc (t: T): U

method next*[T, U](this: MapSkiis[T, U]): Option[U] {.locks: "unknown", base.} =
  let next = this.input.next()
  if next.isSome: some(this.op(next.get))
  else: none(U)

proc initMapSkiis*[T, U](input: Skiis[T], op: proc (t: T): U {.nimcall.}): Skiis[U] =
  let this = new(MapSkiis[T, U])
  this.input = input
  this.op = op
  result = this
