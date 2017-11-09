import
  skiis,
  locks

type
  IteratorSkiis[T] = object
    lock: Lock
    iter {.guard: lock.}: iterator(): T {.closure.}

proc next[T](this: var IteratorSkiis[T]): Option[T] =
  withLock this.lock:
    #echo "locking: " & $cast[int](unsafeAddr(this.lock))
    let tentative = this.iter()
    if not finished(this.iter):
      result = some(tentative)
    else:
      result = none(T)

proc skiisFromIterator*[T](iter: iterator(): T): Skiis[T] =
  var this = IteratorSkiis[T]()
  lockInitWith this.lock:
    this.iter = iter
  result = new Skiis[T]
  result.methods.next = proc(): Option[T] = this.next()
  result.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = this.next(), n)

