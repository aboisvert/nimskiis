import
  test_common,
  os

template declareBuffer*(typ: typedesc) =
  proc `=deepCopy`*(buffer: Buffer[typ]): Buffer[typ] =
    echo "deep copy buffer: " & $cast[int](unsafeAddr(buffer))
    result = buffer
  
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

    test "parMap (1 to 10)":
      let s = countSkiis(1, 3)
      let context = SkiisContext(parallelism: 4, queue: 1, batch: 1)
      let skiis = s.parMap(context) do (x: int) -> int:
        x + 1
      let result = skiis.toSet
      check:
        result == @[2, 3, 4].toSet
