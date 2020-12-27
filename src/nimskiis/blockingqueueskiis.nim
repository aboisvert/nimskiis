import skiis, blockingqueue

#--- BlockingQueue wrapper ---

type
  BlockingQueueSkiis[T] = ref object of Skiis[T]
    queue: BlockingQueue[T]

proc next*[T](this: BlockingQueueSkiis[T]): Option[T] {.locks: "unknown".} =
  let value = this.queue.pop()
  when T is ref:
    # deepCopy refs across threads
    deepCopy(result, value)
  else:
    result = value

proc BlockingQueueSkiis_next[T](this: Skiis[T]): Option[T] {.locks: "unknown".} =
  let this = cast[BlockingQueueSkiis[T]](this)
  this.next()

proc asSkiis*[T](queue: BlockingQueue[T]): Skiis[T] =
  let this = new(BlockingQueueSkiis[T])
  this.nextProc = BlockingQueueSkiis_next[T]
  this.queue = queue
  result = this
