import 
  skiis,
  locks

type SeqSkiis[T] = ref object of Skiis[T]
  lock: Lock
  values {.guard: lock.}: seq[T]
  position {.guard: lock.}: int

proc initSkiis*[T](values: varargs[T]): Skiis[T] =
  let newSkiis = new SeqSkiis[T]
  lockInitWith newSkiis.lock:
    newSkiis.values = @values
    newSkiis.position = 0
  result = newSkiis

method next*[T](skiis: SeqSkiis[T]): Option[T] =
  withLock skiis.lock:
    template pos: int = skiis.position
    if pos < skiis.values.len:
      result = some(skiis.values[pos])
      pos += 1
    else:
      result = none(T)

#proc `=deepCopy`(skiis: SeqSkiis[int]): SeqSkiis[int] =
#  result = skiis

