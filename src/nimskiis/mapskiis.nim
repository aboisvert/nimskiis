import skiis, helpers

type
  MapSkiis[T; U] = object of SkiisObj[U]
    input: Skiis[T]
    op: proc (t: T): U

proc MapSkiis_destructor[T; U](this: var MapSkiis[T, U]) =
  `=destroy`(this.input)

proc `=destroy`[T; U](this: var MapSkiis[T, U]) =
  MapSkiis_destructor(this)

proc next*[T; U](this: ptr MapSkiis[T, U]): Option[U] =
  let next = this.input.next()
  if next.isSome: some(this.op(next.get))
  else: none(U)

proc MapSkiis_next[T; U](this: ptr SkiisObj[U]): Option[U] =
  let this = downcast[U, MapSkiis[T, U]](this)
  this.next()

proc initMapSkiis*[T; U](input: Skiis[T], op: proc (t: T): U): Skiis[U] =
  let this = allocShared0T(MapSkiis[T, U])
  this.nextMethod = MapSkiis_next[T, U]
  this.takeMethod = defaultTake[U]
  this.input = input
  this.op = op
  result = asSharedPtr[U, MapSkiis[T, U]](this, MapSkiis_destructor[T, U])
