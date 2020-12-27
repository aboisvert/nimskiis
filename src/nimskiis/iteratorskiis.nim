import
  helpers,
  skiisops,
  locks

type
  IteratorSkiis[T] = ref object of Skiis[T]
    lock: Lock
    iter {.guard: lock.}: iterator(): T {.closure.}

proc next*[T](this: IteratorSkiis[T]): Option[T] =
  withLock this.lock:
    #echo "locking: " & $cast[int](unsafeAddr(this.lock))
    let tentative = this.iter()
    if not finished(this.iter):
      result = some(tentative)
    else:
      result = none(T)

proc FlatMapSkiis_next[T](this: IteratorSkiis[T]): Option[T] =
  let this = cast[IteratorSkiis[T]](this)
  this.next()

proc skiisFromIterator*[T](iter: iterator(): T): Skiis[T] =
  let this = new(IteratorSkiis[T])
  lockInitWith this.lock:
    this.nextProc = FlatMapSkiis_next[T]
    this.iter = iter
  result = this
