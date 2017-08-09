import
  nimskiis,
  unittest,
  sequtils,
  threadpool

suite "IteratorSkiis":

  proc mycount(a, b: int): iterator (): int =
    result = iterator (): int =
      var x = a
      while x <= b:
        yield x
        inc x

  test "create from iterator":
    let s = skiisFromIterator[int](mycount(1,3))
    check:
      s.next() == some(1)
      s.next() == some(2)
      s.next() == some(3)
      s.next().isNone

  test "concurrent access is deterministic":

    type Result = object
      sum: int64
      consumed: int

    proc count(skiis: Skiis[int]): Result =
      var n = skiis.next
      while n.isSome:
        result.sum += n.get
        result.consumed += 1
        n = skiis.next

    let s = skiisFromIterator[int](mycount(0,100_000))
    var responses = newSeq[FlowVar[Result]](4)
    for i in 0..responses.len-1:
      responses[i] = spawn count(cast[Skiis[int]](s))
    let results: seq[Result] = responses.mapIt(Result, ^it)
    let total = foldl(results, a + b.sum, 0.int64)
    
    check:
      total == 5_000_050_000.int64    

    #for r in results:
    #  echo r.consumed