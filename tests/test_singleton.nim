import
  nimskiis,
  unittest,
  sequtils,
  threadpool

# Get rid of unused module import (for test_all.nim)
{.used.}

suite "Singleton":
  test "create empty singleton skiis":
    let s = initEmptySkiis[int]()
    check: s.next().isNone

  test "create singleton skiis with value":
    var s = initSingletonSkiis(42)
    check:
      s.next() == some(42)
      s.next().isNone

  test "singleton with value take returns a single value":
    var s = initSingletonSkiis(42)
    check:
      s.take(10) == @[42]
      s.take(10) == newSeq[int]()
