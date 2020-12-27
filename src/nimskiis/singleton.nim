import
  skiis,
  helpers,
  locks

type
  SingletonSkiis[T] = ref object of Skiis[T]
    lock: Lock
    value {.guard: lock.}: Option[T]

method next*[T](skiis: SingletonSkiis[T]): Option[T] {.locks: "unknown", base.} =
  withLock skiis.lock:
    result = skiis.value
    if skiis.value.isSome:
      skiis.value = none(T)

proc initSingletonSkiis*[T](value: T): Skiis[T] =
  let this = new(SingletonSkiis[T])
  lockInitWith this.lock:
    this.value = some(value)
  result = this
