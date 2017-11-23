import
  skiis,
  buffer,
  locks

proc newBufferSkiis*[T](values: varargs[T]): (Skiis[T], Buffer[T]) =
  let this = newBuffer[T]()
  let skiis = new Skiis[T]
  skiis.methods.next = proc(): Option[T] = this.pop()
  # todo: optimize take
  skiis.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = this.pop(), n) 
  (skiis, this)
  