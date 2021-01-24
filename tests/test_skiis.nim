import
  test_common,
  nimskiis/sharedptr,
  std/math,
  std/strformat


# Get rid of unused module import (for test_all.nim)
{.used.}

suite "Skiis":

  for i in 0..1: #100_000:

    test fmt"parForeach (1 to 10) {i}":
      let s = newCountSkiis(1, 10000)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      check:
        buffer.toSeq.sum == 50_005_000.int64

    test "parForeach (1 to 1000)":
      let s = newCountSkiis(1, 1000)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      check:
        buffer.toSeq.sum == 500_500.int64

    test "parForeach (1 to 1000) parallelism=2":
      let s = newCountSkiis(1, 1000)
      let context = SkiisContext(parallelism: 2, queue: 1, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      let sum = buffer.toSeq.sum
      check:
        sum == 500500.int64

    test "parForeach (1 to 1000) parallelism=2 queue=10":
      let s = newCountSkiis(1, 1000)
      let context = SkiisContext(parallelism: 2, queue: 10, batch: 1)
      let buffer = newBuffer[int]()
      s.parForeach(context) do (x: int) -> void:
        buffer.push(x)
      let sum = buffer.toSeq.sum
      check:
        sum == 500500.int64

    test fmt"parMap (1 to 10) {i}":
      let s: Skiis[int] = newCountSkiis(1, 3)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)

      #echo "s is ", addressPtr(s.asPtr)
      let skiis = s.parMap(context) do (x: int) -> int:
        x + 1
      let result = skiis.toSet
      check:
        result == @[2, 3, 4].toHashSet

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
        result == @["1", "2", "3"].toHashSet

    test "parMap 1..1000 works with strings":
      let s: Skiis[int] = newCountSkiis(1, 1000)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let skiis = s.parMap(context) do (x: int) -> string:
        $x
      GC_fullCollect()
      let result = skiis.toSet
      GC_fullCollect()
      let expected = sliceToSeq(1 .. 1000).mapIt($it).toHashSet
      check:
        result == expected

  test "parFlatMap @[1, 3, 5])":
    let s: Skiis[int] = initSkiis(@[1, 3, 5])
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let skiis = s.parFlatMap(context) do (x: int) -> seq[int]:
      @[x, x + 1]
    let result = skiis.toSeq
    check:
      result.len == 6
      result.toHashSet == @[1, 2, 3, 4, 5, 6].toHashSet

  test "parReduce @[1, 3, 5])":
    let s: Skiis[int] = initSkiis(@[1, 3, 5])
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let result = s.parReduce(context) do (x: int, y: int) -> int: x + y
    check:
      result == 9

  test "parSum (1 to 10,000)":
    let s: Skiis[int] = newCountSkiis(1, 10_000)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let result = s.parSum(context)
    check:
      result == (1 .. 10000).sum

  test "parFilter @[1, 3, 5])":
    let s: Skiis[int] = initSkiis(@[1, 2, 3, 4, 5])
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let result = s.parFilter(context) do (x: int) -> bool: (x mod 2 == 0)
    check:
      result.toSeq == @[2, 4]

  test "grouped (1..10)":
    let s: Skiis[int] = newCountSkiis(1, 10)
    let grouped = s.grouped(3)
    check:
      grouped.next() == some(@[1, 2, 3])
      grouped.next() == some(@[4, 5, 6])
      grouped.next() == some(@[7, 8, 9])
      grouped.next() == some(@[10])
      grouped.next() == none(seq[int])

  test "lookahead":
    let s: Skiis[int] = newCountSkiis(1, 10)
    let result = s.lookahead(SkiisContext(parallelism: 4, queue: 1, batch: 1))
    check:
      result.toSet == @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].toHashSet

  test "listen":
    let s: Skiis[int] = newCountSkiis(1, 10)
    var buffer = newSeq[int]()
    let result = s.listen do (x: int) -> void:
      buffer.add(x)
    check:
      # order is important here since `result` is lazy
      result.toSet == @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].toHashSet
    check:
      buffer.toHashSet == (@[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].toHashSet)

  test "map (1..10)":
    let s: Skiis[int] = newCountSkiis(1, 10)
    let result = s.map do (x: int) -> int: (x + 1)
    check:
      result.toSet == @[2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].toHashSet

  test "flatMap (1..10)":
    let s: Skiis[int] = initSkiis(@[1, 3, 5])
    let result = s.flatMap do (x: int) -> seq[int]: @[x, x + 1]
    check:
      result.toSet == @[1, 2, 3, 4, 5, 6].toHashSet



  test "flatMap (1..10_000) parSum()":
    let s: Skiis[int] = newCountSkiis(1, 10_000)
    let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
    let result = s.flatMap do (x: int) -> seq[int]:
      if x mod 2 == 0: @[x, x + 1]
      else: @[x, x + 1, x + 2]
    check:
      result.parSum(context) == 125030000

  test "filter (1..10)":
    let s: Skiis[int] = newCountSkiis(1, 10)
    let result = s.filter do (x: int) -> bool: (x mod 2) == 0
    check:
      result.toSet == @[2, 4, 6, 8, 10].toHashSet
