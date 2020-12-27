import test_common

# Get rid of unused module import (for test_all.nim)
{.used.}

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
    let wrapper = allocShared0T(Wrapper[Skiis[int]])
    wrapper.obj = s
    for i in 0..responses.len-1:
      responses[i] = spawn consumeSum(wrapper)
    let results: seq[Sum] = responses.mapIt(^it)
    #for r in results:
    #  echo $r
    check:
      results.sum == 5_000_050_000.int64
    deallocShared(wrapper)
