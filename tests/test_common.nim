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
  unittest,
  sequtils,
  threadpool,
  sets

type Sum* = object
  sum*: int64
  consumed*: int

proc sum*(xs: openarray[Sum]): int64 =
  foldl(xs, a + b.sum, 0.int64)

#proc sum*(xs: openarray[int]): int64 =
#  foldl(xs, a + b, 0.int64)

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

proc consumeSum*(skiis: SkiisPtr[int]): Sum =
  asRef(skiis).foreach(n):
    result.sum += n
    result.consumed += 1

proc countSkiis*(i: int, j: int): Skiis[int] =
   skiisFromIterator[int](countIterator(i, j))

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
