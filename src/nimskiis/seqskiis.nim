import
  skiis,
  helpers,
  locks

type
  SeqSkiis[T] = ref object of Skiis[T]
    lock: Lock
    values {.guard: lock.}: seq[T]
    position {.guard: lock.}: int

method next*[T](this: SeqSkiis[T]): Option[T] {.locks: "unknown".} =
  withLock this.lock:
    template pos: int = this.position
    if pos < this.values.len:
      result = some(this.values[pos])
      inc pos
    else:
      result = none(T)

proc initSkiis*[T](values: varargs[T]): Skiis[T] =
  let this = new(SeqSkiis[T])
  lockInitWith this.lock:
    this.values = @values
    this.position = 0
  result = this
