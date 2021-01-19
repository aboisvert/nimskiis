import
  skiis,
  helpers,
  buffer,
  list

type
  FlatMapSkiis[T, U] = ref object of Skiis[U]
    input: Skiis[T]
    op: proc (t: T): List[U]
    buffer: Buffer[T]
    lock: Lock
    consumers: int
    producers: int
    noMore: bool
    consumerFinished: Cond

proc next*[T, U](this: FlatMapSkiis[T, U]): Option[U] =
  while true:
    block:
      let buffered = this.buffer.pop()
      if buffered.isSome:
        this.consumerFinished.signal()
        return buffered

    withLock this.lock:
      if this.noMore and this.producers == 0:
        release(this.lock)
        return none(T)

    let next = this.input.next()
    if next.isSome:
      var results = deepClone(this.op(next.get))
      results.foreach(r):
        this.buffer.push(r)
      results.disposeList()
      withLock this.lock:
        this.producers -= 1
      this.consumerFinished.signal()
    else:
      withLock this.lock:
        if this.noMore:
          if this.producers > 1:
            this.consumerFinished.wait(this.lock)
          else:
            this.consumers -= 1
            this.consumerFinished.signal()
            release(this.lock)
            return none(T)
        else:
          this.noMore = true

proc FlatMapSkiis_next[T, U](this: Skiis[T]): Option[T] =
  let this = cast[FlatMapSkiis[T, U]](this)
  this.next()


proc initFlatMapSkiis*[T, U](input: Skiis[T], op: proc (t: T): List[U] {.nimcall.}): Skiis[U] =
  let this = new(FlatMapSkiis[T, U])
  this.nextMethod = FlatMapSkiis_next[T, U]
  this.takeMethod = defaultTake[T]
  this.input = input
  this.op = op
  this.buffer = newBuffer[U]()
  initLock(this.lock)
  initCond(this.consumerFinished)
  result = this
