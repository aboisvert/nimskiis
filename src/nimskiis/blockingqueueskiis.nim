import skiis, blockingqueue, sharedptr, helpers

#--- BlockingQueue wrapper ---

type
  BlockingQueueSkiis*[T] = object of SkiisObj[T]
    queue: ptr BlockingQueue[T] # owned

proc BlockingQueueSkiis_destructor[T](this: var BlockingQueueSkiis[T]) =
  #echo "destroy call on BlockingQueueSkiisObj"
  if this.queue != nil:
    `=destroy`(this.queue[])
    deallocShared(this.queue)
    this.queue = nil

proc `=destroy`*[T](this: var BlockingQueueSkiis[T]) =
  BlockingQueueSkiis_destructor(this)

proc next[T](this: ptr BlockingQueueSkiis[T]): Option[T] =
  result = this.queue[].pop()

proc BlockingQueueSkiis_next[T](this: ptr SkiisObj[T]): Option[T] =
  let this = downcast[T, BlockingQueueSkiis[T]](this)
  this.next()

proc asSkiis*[T](queue: ptr BlockingQueue[T]): Skiis[T] =
  let this = allocShared0T(BlockingQueueSkiis[T])
  this.nextMethod = BlockingQueueSkiis_next[T]
  this.takeMethod = defaultTake[T]
  this.queue = queue
  result = asSharedPtr[T, BlockingQueueSkiis[T]](this, BlockingQueueSkiis_destructor[T])
