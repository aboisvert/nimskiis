import
  test_common

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
    let numbers: seq[int] = sliceToSeq(0 .. 100_000)
    let s = initSkiis(numbers)
    var responses = newSeq[FlowVar[Sum]](4)
    let wrapper = allocShared0T(Wrapper[Skiis[int]])
    wrapper.obj = s
    for i in 0..responses.len-1:
      responses[i] = spawn consumeSum(wrapper)
    let results: seq[Sum] = responses.mapIt(^it)
    check:
      sum(results) == 5_000_050_000.int64
    deallocShared(wrapper)
    #for r in results:
    #  echo r.consumed
