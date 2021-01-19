import skiis

type
  MapSkiis[T, U] = ref object of Skiis[U]
    input: Skiis[T]
    op: proc (t: T): U

proc next*[T, U](this: MapSkiis[T, U]): Option[U] =
  let next = this.input.next()
  if next.isSome: some(this.op(next.get))
  else: none(U)

proc MapSkiis_next[T, U](this: Skiis[U]): Option[U] =
  let this = cast[MapSkiis[T, U]](this)
  this.next()

proc initMapSkiis*[T, U](input: Skiis[T], op: proc (t: T): U {.nimcall.}): Skiis[U] =
  let this = new(MapSkiis[T, U])
  this.nextMethod = MapSkiis_next[T, U]
  this.takeMethod = defaultTake[T]
  this.input = input
  this.op = op
  result = this
