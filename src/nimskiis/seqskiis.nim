import
  skiis,
  helpers,
  locks

type
  SeqSkiis[T] = object
    lock: Lock
    values {.guard: lock.}: seq[T]
    position {.guard: lock.}: int

proc next[T](this: var SeqSkiis[T]): Option[T] =
  withLock this.lock:
    template pos: int = this.position
    if pos < this.values.len:
      result = some(this.values[pos])
      inc pos
    else:
      result = none(T)

proc initSkiis*[T](values: varargs[T]): Skiis[T] =
  var this = SeqSkiis[T]()
  lockInitWith this.lock:
    this.values = @values
    this.position = 0
  new(result, dispose[T])
  result.methods.next = proc(): Option[T] = this.next()
  result.methods.take = proc(n: int): seq[T] = genericTake(proc(): Option[T] = this.next(), n)
  result.methods.dispose = proc(): void = discard
