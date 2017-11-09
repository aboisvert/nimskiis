import
  nimskiis,
  unittest

suite "Empty Skiis":
  test "create empty skiis":
    let s: Skiis[int] = initEmptySkiis[int]()
    check: s.next().isNone

  test "take() returns empty seq":
    let s = initEmptySkiis[int]()
    check: s.take(10) == newSeq[int]()

#  test "foo":
#    let s = skiisFro



