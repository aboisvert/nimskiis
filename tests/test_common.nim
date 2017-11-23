import
  nimskiis,
  nimskiis/buffer,
  unittest,
  sequtils,
  threadpool,
  sets

export
  nimskiis,
  buffer,
  unittest,
  sequtils,
  threadpool,
  sets

type Sum* = object
  sum*: int64
  consumed*: int

proc sum*(xs: openarray[Sum]): int64 =
  foldl(xs, a + b.sum, 0.int64)

proc sum*(xs: openarray[int]): int64 =
  foldl(xs, a + b, 0.int64)

proc sum*(xs: iterator(): int {.closure.}): int64 =
  for x in xs():
    result += x

proc countIterator(a, b: int): iterator (): int =
  result = iterator (): int =
    var x = a
    while x <= b:
      yield x
      inc x

proc consumeSum*(skiis: Skiis[int]): Sum =
  skiis.foreach(n):
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