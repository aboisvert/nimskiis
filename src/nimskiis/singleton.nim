import
  skiis,
  helpers,
  std/locks

type
  SingletonSkiis[T] = object of SkiisObj[T]
    lock: Lock
    value {.guard: lock.}: Option[T]

proc SingletonSkiis_destroy[T](this: var SingletonSkiis[T]) =
  deinitLock(this.lock)

proc `=destroy`[T](this: var SingletonSkiis[T]) =
  SingletonSkiis_destroy(this)

proc next[T](skiis: ptr SingletonSkiis[T]): Option[T] =
  withLock skiis.lock:
    result = skiis.value
    if skiis.value.isSome:
      skiis.value = none(T)

proc SingletonSkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  let this = downcast[T, SingletonSkiis[T]](this)
  this.next()

proc initSingletonSkiis*[T](value: T): Skiis[T] =
  let this: ptr SingletonSkiis[T] = allocShared0T(SingletonSkiis[T])
  lockInitWith this.lock:
    this.nextMethod = SingletonSkiis_next[T]
    this.takeMethod = defaultTake[T]
    this.value = some(value)
  result = asSharedPtr[T, SingletonSkiis[T]](this, SingletonSkiis_destroy)
