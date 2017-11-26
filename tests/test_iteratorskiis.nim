import
  test_common

suite "IteratorSkiis":

  test "create from iterator":
    let s = countSkiis(1, 3)
    check:
      s.next() == some(1)
      s.next() == some(2)
      s.next() == some(3)
      s.next().isNone

  test "concurrent access is deterministic":
    let s = countSkiis(0, 100_000)
    var responses = newSeq[FlowVar[Sum]](4)
    for i in 0..responses.len-1:
      responses[i] = spawn consumeSum(s)
    let results: seq[Sum] = responses.mapIt(^it)
    check:
      results.sum == 5_000_050_000.int64

    #for r in results:
    #  echo r.consumed