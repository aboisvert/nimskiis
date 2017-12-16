import
  skiis,
  helpers,
  buffer

type
  FlatMapSkiis[T, U] = ref object of Skiis[U]
    input: Skiis[T]
    op: proc (t: T): seq[U]
    buffer: Buffer[T]
    lock: Lock
    consumers: int
    noMore: bool
    consumerFinished: Cond

method next*[T, U](this: FlatMapSkiis[T, U]): Option[U] =
  while true:
    block:
      let buffered = this.buffer.pop()
      if buffered.isSome: return buffered

    var noMore: bool
    var consumers = 0
    withLock this.lock:
      noMore = this.noMore
      consumers = this.consumers
      if not noMore:
        this.consumers += 1

    if noMore:
      if consumers == 0: return none(U)
      this.consumerFinished.wait(this.lock)

    var next = this.input.next()
    #when T is ref: deepCopy(next, next)

    if next.isSome:
      let results = this.op(next.get)
      for r in results:
        this.buffer.push(r)
      withLock this.lock:
        dec(this.consumers)
    else:
      var consumers = 0
      withLock this.lock:
        this.noMore = true
        this.consumers -= 1
        consumers = this.consumers

    this.consumerFinished.signal()

proc initFlatMapSkiis*[T, U](input: Skiis[T], op: proc (t: T): seq[U] {.nimcall.}): Skiis[U] =
  let this = new(FlatMapSkiis[T, U])
  this.input = input
  this.op = op
  this.buffer = newBuffer[U]()
  initLock(this.lock)
  initCond(this.consumerFinished)
  result = this
