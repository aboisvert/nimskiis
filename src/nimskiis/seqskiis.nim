import
  skiis,
  helpers,
  std/locks

type
  SeqSkiis*[T] = object of SkiisObj[T]
    lock: Lock
    values: seq[T] # {.guard: lock.}
    position: int #{.guard: lock.}

proc SeqSkiis_destroy[T](this: var SeqSkiis[T]) =
  #echo "SeqSkiis_destroy"
  deinitLock(this.lock)
  this.values = @[]

proc `=destroy`[T](this: var SeqSkiis[T]) =
  SeqSkiis_destroy(this)

proc SeqSkiis_next[T](this: ptr SeqSkiis[T]): Option[T] =
  #echo "SeqSkiis.next"
  withLock this.lock:
    #echo "SeqSkiis.next withLock"
    template pos: var int = this.position
    if pos < this.values.len:
      result = some(this.values[pos])
      inc pos
    else:
      result = none(T)
    #echo "return ", result

proc SeqSkiis_next1[T](this: ptr SkiisObj[T]): Option[T] =
  let this = cast[ptr SeqSkiis[T]](this)
  SeqSkiis_next(this)

proc initSkiis*[T](values: varargs[T]): Skiis[T] =
  let this = allocShared0T(SeqSkiis[T])
  lockInitWith this.lock:
    this[].takeMethod = defaultTake[T]
    this[].nextMethod = SeqSkiis_next1[T]
    this[].values = @values
    this[].position = 0

  result = asSharedPtr[T, SeqSkiis[T]](this, SeqSkiis_destroy[T])
