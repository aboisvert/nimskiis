import
  skiis,
  locks

type SingletonSkiis[T] = ref object of Skiis[T]
  lock: Lock
  value {.guard: lock.}: Option[T]

proc initSingletonSkiis*[T](value: T): Skiis[T] =
  let newSkiis = new SingletonSkiis[T]
  lockInitWith newSkiis.lock:
    newSkiis.value = some(value)
  result = newSkiis

method next*[T](skiis: SingletonSkiis[T]): Option[T] =
  withLock skiis.lock:
    result = skiis.value
    if skiis.value.isSome:
      skiis.value = none(T)
