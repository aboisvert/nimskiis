#
# Concurrent (thread-safe) bounded-size blocking queue.
#
# Basically a multable seq with maximum allowable size, with push() and pop() semantics.
#
# Note that push() and pop() generally (but not strictly) follow FIFO semantics.
# As such, consumers should generally treat BlockingQueue as an unordered collection.
# Push() may not append at the end of the buffer and so n that sense, BlokingQueue is
# more like an unordered bag and isn't "fair" from a concurrency standpoint.
#

import
  std/options,
  std/locks,
  std/os,
  helpers,
  sharedptr

const
  ElemsPerNode = 100

type
  Node[T] = ptr object
    elems: array[ElemsPerNode, T]
    next: Node[T]
    first, last: int

  BlockingQueue*[T] = object
    head, tail: Node[T]
    size, maxSize: int
    lock*: Lock
    nonEmpty, nonFull: Cond
    closed: bool

template withLock(t, x: untyped) =
  acquire(t.lock)
  try:
    x
  finally:
    release(t.lock)

template foreachNode[T](t: BlockingQueue[T], varName, code: untyped) =
  var varName = t.head
  while varName != nil:
    let next = varName.next # save `next` since node could be deallocated
    code
    varName = next

proc `=destroy`*[T](t: var BlockingQueue[T]) =
  when defined(debugQueue):
    echo "destroy call on BlockingQueueObj"
  if t.head != nil:
    withLock(t):
      t.foreachNode(node):
        deallocShared(node)
      t.head = nil
      t.tail = nil
    deinitLock t.lock
    deinitCond t.nonEmpty
    deinitCond t.nonFull

proc init[T](this: var BlockingQueue[T], maxSize: int) =
  this.head = nil
  this.tail = nil
  this.size = 0
  this.maxSize = maxSize
  initLock this.lock
  initCond this.nonEmpty
  initCond this.nonFull

proc newBlockingQueuePtr*[T](maxSize: int): ptr BlockingQueue[T] =
  result = allocShared0T(BlockingQueue[T])
  init(result[], maxSize)

proc newBlockingQueue*[T](maxSize: int): ref BlockingQueue[T] =
  new(result)
  init(result[], maxSize)

# should be called with lock
proc `$`*[T](this: BlockingQueue[T]): string =
  result = "BlockingQueue("
  result = result & addressRef(this) & ", "
  result = result & "head=" & addressObj(this.head[])
  result = result & ", tail=" & addressObj(this.tail[])
  result = result & ", size=" & $this.size
  result = result & ", maxSize=" & $this.maxSize
  this[].foreachNode(node):
    result = result & ", node#" & addressObj(node[]) & "("
    result = result & "first=" & $node.first
    result = result & ",last=" & $node.last & ")"
  result = result & ")"

proc pop*[T](this: var BlockingQueue[T]): Option[T] =
  withLock(this):
    var found = false
    var wasFull = false
    template head: Node[T] = this.head
    template tail: Node[T] = this.tail
    template first: int = head.first
    template last: int = head.last
    while not found:
      if head != nil and first < last:
        when defined(debugQueue):
          echo "pop - size before ", this.size
        found = true
        result = some(head.elems[first]) # need explicit move()??
        when defined(debugQueue):
          let str = $result.get
          echo "pop - result ", str
        inc(first)
        if this.size == this.maxSize:
          wasFull = true
        dec(this.size)
        when defined(debugQueue):
          echo "pop - size after ", this.size
        if first == last and tail != head:
          when defined(debugQueue):
            echo "dealloc node"
          let delete = head
          head = head.next
          deallocShared(delete)
      elif this.closed:
        found = true
        result = none(T)
      else:
        this.nonEmpty.wait(this.lock)
        this.nonEmpty.signal() # chained broadcast

    if wasFull:
      this.nonfull.signal()

iterator mitems*[T](this: var BlockingQueue[T]): int =
  var x = this.pop()
  while x.isSome:
    yield x.get
    x = this.pop()

proc push*[T](this: var BlockingQueue[T]; y: sink T): void =
  #echo "enter push ", y
  withLock(this):
    when defined(debugQueue):
      echo "push - ", y
      echo "push - size before ", this.size
    if this.closed:
      raise newException(Defect, "Cannot push to a closed BlockingQueue")
    var receivedSignal = false
    while this.size >= this.maxSize and not this.closed:
      when defined(debugQueue):
        echo "full wait!!! ", this.size
      this.nonFull.wait(this.lock)
      receivedSignal = true
    if receivedSignal:
      when defined(debugQueue):
        echo "full resume ", this.size
      this.nonFull.signal() # chained broadcast
    if this.closed:
      raise newException(Defect, "Cannot push to a closed BlockingQueue")

    let sizeBefore = this.size
    var node = this.tail
    if node == nil or (node.first == 0 and node.last == ElemsPerNode):
      when defined(debugQueue):
        echo "alloc node"
      node = cast[type node](allocShared0(sizeof(node[])))
      node.next = nil
      node.first = 0
      node.last = 0
      if this.tail != nil: this.tail.next = node
      this.tail = node
      if this.head == nil: this.head = node
    if node.last < ElemsPerNode:
      #echo "before assign"
      node.elems[node.last] = y
      #echo "after assign"

      inc(node.last)
    elif node.first > 0:
      dec(node.first)
      #echo "before assign2"
      node.elems[node.first] = y
      #echo "after assign2"
    else:
      raise newException(Defect, "WTF!")
    inc(this.size)
    when defined(debugQueue):
      echo "push - size after ", this.size
    if sizeBefore == 0:
      this.nonEmpty.signal()

proc toSeq*[T](buf: BlockingQueue[T]): seq[T] =
  result = newSeq[T]()
  for x in buf.items:
    result.add(x)

proc close*[T](this: var BlockingQueue[T]): void =
  #echo "BlockingQueue.close() ", $this
  withLock(this):
    this.closed = true
    this.nonEmpty.signal()
    this.nonFull.signal()
