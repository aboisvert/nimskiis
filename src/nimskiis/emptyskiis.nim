import skiis

type EmptySkiis[T] = object

proc next[T](this: EmptySkiis[T]): Option[T] =
  result = none(T)

proc take[T](this: EmptySkiis[T], n: int): seq[T] =
  result = newSeq[T]()

proc initEmptySkiis*[T](): Skiis[T] =
  let this = EmptySkiis[T]()
  new(result, dispose[T])
  result.methods.next = proc(): Option[T] = this.next()
  result.methods.take = proc(n: int): seq[T] = this.take(n)
  result.methods.dispose = proc(): void = discard


