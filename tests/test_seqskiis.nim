import
  nimskiis,
  unittest,
  sequtils,
  threadpool

suite "SeqSkiis":

  test "create empty seqskiis":
    let s = initSkiis[int]()
    check: s.next().isNone

  test "initialize with literal values":
    let s = initSkiis(1, 2, 3)
    check:
      s.next() == some(1)
      s.next() == some(2)
      s.next() == some(3)
      s.next().isNone

  test "initialize using array":
    let s = initSkiis[int](@[1, 2, 3])
    check:
      s.next() == some(1)
      s.next() == some(2)
      s.next() == some(3)
      s.next().isNone

  test "take returns values":
    let s = initSkiis(1, 2, 3)
    check:
      s.take(10) == @[1, 2, 3]
      s.take(10) == newSeq[int]()
      
  test "take may return subset of values":
    let s = initSkiis(1, 2, 3, 4, 5, 6)
    check:
      s.take(2) == @[1, 2]
      s.take(2) == @[3, 4]
      s.take(1) == @[5]
      s.take(0) == newSeq[int]()
      s.take(2) == @[6]
      s.take(10) == newSeq[int]()

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

    let numbers: seq[int] = toSeq(0..100_000)
    let s = initSkiis(numbers)
    var responses = newSeq[FlowVar[Result]](4)
    for i in 0..responses.len-1:
      responses[i] = spawn count(cast[Skiis[int]](s))
    let results: seq[Result] = responses.mapIt(Result, ^it)
    let total = foldl(results, a + b.sum, 0.int64)
    
    check:
      total == 5_000_050_000.int64    

    for r in results:
      echo r.consumed