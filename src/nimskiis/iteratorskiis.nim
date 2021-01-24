import
  helpers,
  skiis,
  locks

type
  IteratorSkiis[T] = object of SkiisObj[T]
    lock: Lock
    iter {.guard: lock.}: iterator(): T {.closure.}

proc next*[T](this: var IteratorSkiis[T]): Option[T] =
  withLock this.lock:
    #echo "locking: " & $cast[int](unsafeAddr(this.lock))
    let tentative = this.iter()
    if not finished(this.iter):
      result = some(tentative)
    else:
      result = none(T)

proc FlatMapSkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  let this = downcast[T, IteratorSkiis](this)
  this.next()

proc skiisFromIterator*[T](iter: iterator(): T): Skiis[T] =
  var this: IteratorSkiis[T]
  lockInitWith this.lock:
    this.nextMethod = FlatMapSkiis_next[T]
    this.takeMethod = defaultTake[T]
    this.iter = iter
  result = asSharedPtr[T](this)
