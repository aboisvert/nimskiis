import
  nimskiis,
  nimskiis/buffer,
  nimskiis/blockingqueue,
  nimskiis/helpers,
  nimskiis/sharedptr,
  std/unittest,
  std/sequtils,
  std/locks,
  std/threadpool,
  std/sets,
  std/sugar

export
  nimskiis,
  buffer,
  blockingqueue,
  helpers,
  unittest,
  sequtils,
  threadpool,
  sets,
  sugar

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


proc consumeSum*(skiis: Skiis[int]): Sum =
  skiis.foreach(n):
    result.sum += n
    result.consumed += 1

type
  CountSkiis = object of SkiisObj[int]
    lock: Lock
    current: int
    stop: int
    step: int

proc CountSkiis_destructor(this: var CountSkiis) =
  #echo "CountSkiis.destructor"
  release(this.lock)

proc `=destroy`(this: var CountSkiis) =
  #echo "CountSkiis.destroy"
  CountSkiis_destructor(this)

proc `$`*(this: CountSkiis): string =
  "CountSkiis(current=" & $this.current &
    ", stop=" & $this.stop & ", step=" & $this.step & ")"

proc CountSkiis_next(this: ptr CountSkiis): Option[int] =
  withLock this.lock:
    #echo "CountSkiis_next4 ", addressPtr(this)
    #echo "CountSkiis_next5 ", $this[]
    if this.current <= this.stop:
      result = some(this.current)
      inc(this.current, this.step)
    else:
      result = none(int)

proc CountSkiis_next[T: int](this: ptr SkiisObj[T]): Option[int] =
  let this = downcast[int, CountSkiis](this)
  this.CountSkiis_next()

proc newCountSkiis*(start: int, stop: int, step: int = 1): Skiis[int] =
  #skiisFromIterator[int](countIterator(i, j))
  let this = allocShared0T(CountSkiis)
  this.current = start
  this.stop = stop
  this.step = step
  this.nextMethod = CountSkiis_next[int]
  this.takeMethod = defaultTake[int]
  initLock(this.lock)
  result = asSharedPtr[int, CountSkiis](this, CountSkiis_destructor)

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
