import
  nimskiis,
  nimskiis/buffer,
  nimskiis/blockingqueue,
  nimskiis/helpers,
  unittest,
  sequtils,
  threadpool,
  sets

export
  nimskiis,
  buffer,
  blockingqueue,
  helpers,
  unittest,
  sequtils,
  threadpool,
  sets

# Get rid of unused module import (for test_all.nim)
{.used.}

type Sum* = object
  sum*: int64
  consumed*: int

proc sum*(xs: openarray[Sum]): int64 =
  foldl(xs, a + b.sum, 0.int64)

proc sum*(xs: iterator(): int {.closure.}): int64 =
  for x in xs():
    result += x

proc sum*[T](xs: Slice[T]): T =
  for x in xs.items:
    result += x

proc countIterator*(a, b: int): iterator (): int =
  result = iterator (): int =
    var x = a
    while x <= b:
      yield x
      inc x

proc consumeSum*(skiis: ptr Wrapper[Skiis[int]]): Sum =
  (skiis.obj).foreach(n):
    result.sum += n
    result.consumed += 1

type
  CountSkiis = ref object of Skiis[int]
    lock: Lock
    current: int
    stop: int
    step: int

proc next*(this: CountSkiis): Option[int] =
  withLock this.lock:
    if this.current <= this.stop:
      result = some(this.current)
      inc(this.current, this.step)
    else:
      result = none(int)

proc CountSkiis_next[T: int](this: Skiis[T]): Option[T] =
  let this = cast[CountSkiis](this)
  this.next()

proc countSkiis*(start: int, stop: int, step: int = 1): Skiis[int] =
  #skiisFromIterator[int](countIterator(i, j))
  let this = CountSkiis(current: start, stop: stop, step: step)
  this.nextMethod = CountSkiis_next[int]
  this.takeMethod = defaultTake[int]
  initLock(this.lock)
  result = this

proc sliceToSeq*[T](s: Slice[T]): seq[T] =
  result = newSeq[T](ord(s.b) - ord(s.a) + 1)
  var i = 0
  for x in s.a .. s.b:
    result[i] = x
    inc(i)

proc toSet*[T](skiis: Skiis[T]): HashSet[T] =
  init(result)
  skiis.foreach(n):
    result.incl(n)

proc toSet*[T](iter: iterator(): T): HashSet[T] =
  init(result)
  for x in iter():
    result.incl(x)

proc sumRange*(low, high, step: int): int =
  var x = low
  while x <= high:
    result += x
    x += step