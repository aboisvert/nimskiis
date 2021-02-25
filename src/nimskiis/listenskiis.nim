import skiis, helpers

type
  ListenSkiis[T] = object of SkiisObj[T]
    input: Skiis[T]
    op: proc (t: T): void

proc ListenSkiis_destructor[T](this: var ListenSkiis[T]) =
  `=destroy`(this.input)

proc `=destroy`[T](this: var ListenSkiis[T]) =
  ListenSkiis_destructor(this)

proc next*[T](this: ptr ListenSkiis[T]): Option[T] =
  let next = this.input.next()
  if next.isSome:
    try:
      this.op(next.get)
    except:
      let e = getCurrentException()
      let msg = getCurrentExceptionMsg()
      echo "Skiis.listen() - exception ", repr(e), " with message ", msg
  next

proc ListenSkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  let this = downcast[T, ListenSkiis[T]](this)
  this.next()

proc initListenSkiis*[T](input: Skiis[T], op: proc (t: T): void): Skiis[T] =
  let this = allocShared0T(ListenSkiis[T])
  this.nextMethod = ListenSkiis_next[T]
  this.takeMethod = defaultTake[T]
  this.input = input
  this.op = op
  result = asSharedPtr[T, ListenSkiis[T]](this, ListenSkiis_destructor[T])
