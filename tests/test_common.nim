import
  nimskiis,
  unittest,
  sequtils,
  threadpool,
  lockedlist

export
  nimskiis,
  unittest,
  sequtils,
  threadpool

declareSkiis(int)

type Sum* = object
  sum*: int64
  consumed*: int

proc sum*(xs: openarray[Sum]): int64 =
  foldl(xs, a + b.sum, 0.int64)

proc countIterator(a, b: int): iterator (): int =
  result = iterator (): int =
    var x = a
    while x <= b:
      yield x
      inc x

proc consumeSum*(skiis: Skiis[int]): Sum =
  var n = skiis.next()
  while n.isSome:
    result.sum += n.get
    result.consumed += 1
    n = skiis.next()

proc countSkiis*(i: int, j: int): Skiis[int] =
   skiisFromIterator[int](countIterator(i, j))

proc sliceToSeq*[T](s: Slice[T]): seq[T] =
  result = newSeq[T](ord(s.b) - ord(s.a) + 1)
  var i = 0
  for x in s.a .. s.b:
    result[i] = x
    inc(i)

proc toSeq*[T](s: var SharedList[T]): seq[T] =
  result = newSeq[T]()
  for x in s.items:
    result.add(x)
