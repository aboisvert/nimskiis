import skiis, std/locks, helpers

type
  FlatMapSkiis[T, U] = object of SkiisObj[U]
    input: Skiis[T]
    op: proc (t: T): seq[U]
    buffer: seq[U]
    lock: Lock
    producers: int
    noMore: bool
    produced: Cond

proc FlatMapSkiis_destructor[T; U](this: var FlatMapSkiis[T, U]) =
  deinitCond(this.produced)
  deinitLock(this.lock)

proc `=destroy`[T; U](this: var FlatMapSkiis[T, U]) =
  FlatMapSkiis_destructor(this)

proc next[T; U](this: ptr FlatMapSkiis[T, U]): Option[U] =
  while true:
    withLock this.lock:
      # fast path
      if this.buffer.len > 0:
        return some(this.buffer.pop())

      if this.noMore and this.producers == 0:
        return none(U)

      inc(this.producers)

    let next = this.input.next()
    if next.isSome:
      let results = this.op(next.get)
      withLock this.lock:
        dec(this.producers)
        if results.len > 0:
          for r in results[1..^1]: this.buffer.add(r)
          this.produced.signal()
          return some(results[0])
    else:
      withLock this.lock:
        dec(this.producers)
        if this.producers > 0:
          this.produced.wait(this.lock)
          this.produced.signal() # chained broadcast
        else:
          this.noMore = true
          this.produced.signal()
          return none(U)

proc FlatMapSkiis_next[T; U](this: ptr SkiisObj[U]): Option[U] =
  let this = downcast[U, FlatMapSkiis[T, U]](this)
  next[T, U](this)

proc initFlatMapSkiis*[T; U](
  input: Skiis[T],
  op: proc (t: T): seq[U]
): Skiis[U] =
  let this = allocShared0T(FlatMapSkiis[T, U])
  this.nextMethod = FlatMapSkiis_next[T, U]
  this.takeMethod = defaultTake[U]
  this.input = input
  this.op = op
  this.buffer = newSeqOfCap[U](16)
  initLock(this.lock)
  initCond(this.produced)
  result = asSharedPtr[U, FlatMapSkiis[T, U]](this, FlatMapSkiis_destructor[T, U])
