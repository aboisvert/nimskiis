import
  test_common,
  lockedlist,
  os

suite "Skiis":

  test "parForeach (1 to 10)":
    let s = countSkiis(1, 10)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    var sharedList = initSharedList[int]()
    s.parForeach(context) do (x: int) -> void:
      sharedList.add(x)
    check:
      foldl(sharedList, a + b, 0.int64).int64 == 55

  test "parForeach (1 to 1000)":
    let s = countSkiis(1, 1000)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    var sharedList = initSharedList[int]()
    s.parForeach(context) do (x: int) -> void:
      sharedList.add(x)
    check:
      foldl(sharedList, a + b, 0.int64) == 500500.int64

    test "parForeach (1 to 1000) parallelism=2":
      let s = countSkiis(1, 1000)
      let context = SkiisContext(parallelism: 2, queue: 1, batch: 1)
      var sharedList = initSharedList[int]()
      s.parForeach(context) do (x: int) -> void:
        sharedList.add(x)
      check:
        foldl(sharedList, a + b, 0.int64) == 500500.int64
