import
  skiis,
  helpers,
  locks

type
  SingletonSkiis[T] = ref object of Skiis[T]
    lock: Lock
    value {.guard: lock.}: Option[T]

proc next*[T](skiis: SingletonSkiis[T]): Option[T] =
  withLock skiis.lock:
    result = skiis.value
    if skiis.value.isSome:
      skiis.value = none(T)

proc SingletonSkiis_next[T](this: Skiis[T]): Option[T] =
  let this = cast[SingletonSkiis[T]](this)
  this.next()

proc initSingletonSkiis*[T](value: T): Skiis[T] =
  let this = new(SingletonSkiis[T])
  lockInitWith this.lock:
    this.nextMethod = SingletonSkiis_next[T]
    this.takeMethod = defaultTake[T]
    this.value = some(value)
  result = this
