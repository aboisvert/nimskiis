import 
  skiis,
  locks

type IteratorSkiis[T] = ref object of Skiis[T]
  lock: Lock
  iter {.guard: lock.}: iterator(): T {.closure.}

proc skiisFromIterator*[T](iter: iterator(): T): Skiis[T] =
  let newSkiis = new IteratorSkiis[T]
  lockInitWith newSkiis.lock:
    newSkiis.iter = iter
  result = newSkiis

method next*[T](skiis2: IteratorSkiis[T]): Option[T] =
  withLock skiis2.lock:
    let tentative = skiis2.iter()
    if not finished(skiis2.iter):
      result = some(tentative)
    else:
      result = none(T)

