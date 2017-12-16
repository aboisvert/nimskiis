import skiis, blockingqueue

#--- BlockingQueue wrapper ---

type
  BlockingQueueSkiis[T] = ref object of Skiis[T]
    queue: BlockingQueue[T]

proc asSkiis*[T](queue: BlockingQueue[T]): Skiis[T] =
  let this = new(BlockingQueueSkiis[T])
  this.queue = queue
  result = this

method next*[T](this: BlockingQueueSkiis[T]): Option[T] {.locks: "unknown".} =
  let value = this.queue.pop()
  when T is ref:
    # deepCopy refs across threads
    deepCopy(result, value)
  else:
    result = value
