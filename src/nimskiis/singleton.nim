import
  skiis,
  helpers,
  locks

type
  SingletonSkiis[T] = object
    lock: Lock
    value {.guard: lock.}: Option[T]

proc next[T](skiis: var SingletonSkiis[T]): Option[T] =
  withLock skiis.lock:
    result = skiis.value
    if skiis.value.isSome:
      skiis.value = none(T)

proc initSingletonSkiis*[T](value: T): Skiis[T] =
  var this = SingletonSkiis[T]()
  lockInitWith this.lock:
    this.value = some(value)
  result = new Skiis[T]
  result.methods.next = proc(): Option[T] = this.next()
  result.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = this.next(), n)

