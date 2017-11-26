import test_common

suite "Skiis":

  test "parForeach (1 to 10)":
    let s = countSkiis(1, 10)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let buffer = newBuffer[int]()
    s.parForeach(context) do (x: int) -> void:
      buffer.push(x)
    check:
      buffer.toSeq.sum == 55

  test "parForeach (1 to 1000)":
    let s = countSkiis(1, 1000)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let buffer = newBuffer[int]()
    s.parForeach(context) do (x: int) -> void:
      buffer.push(x)
    check:
      buffer.toSeq.sum == 500500.int64

    test "parForeach (1 to 1000) parallelism=2":
      let s = countSkiis(1, 1000)
      let context = SkiisContext(parallelism: 2, queue: 1, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      let sum = buffer.toSeq.sum
      check:
        sum == 500500.int64

    test "parForeach (1 to 1000) parallelism=2 queue=10":
      let s = countSkiis(1, 1000)
      let context = SkiisContext(parallelism: 2, queue: 10, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      let sum = buffer.toSeq.sum
      check:
        sum == 500500.int64

    test "parMap (1 to 10)":
      let s: Skiis[int] = countSkiis(1, 3)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let skiis = s.parMap(context) do (x: int) -> int:
        x + 1
      let result = skiis.toSet
      check:
        result == @[2, 3, 4].toSet

    test "parMap 1.. 3 works with strings":
      let s = @[1, 2, 3]
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let skiis = initSkiis(s).parMap(context) do (x: int) -> string:
        GC_fullCollect()
        $x
      GC_fullCollect()
      let result = skiis.toSet
      GC_fullCollect()
      check:
        result == @["1", "2", "3"].toSet

    test "parMap 1..1000 works with strings":
      let s: Skiis[int] = countSkiis(1, 1000)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let skiis = s.parMap(context) do (x: int) -> string:
        # fullCollect doesn't seem legal in this context, causes:
        #   SIGSEGV: Illegal storage access. (Attempt to read from nil?)
        # GC_fullCollect()
        $x
      GC_fullCollect()
      let result = skiis.toSet
      GC_fullCollect()
      let expected = sliceToSeq(1 .. 1000).mapIt($it).toSet
      check:
        result == expected
