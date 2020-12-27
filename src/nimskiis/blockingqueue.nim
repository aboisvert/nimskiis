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
  options,
  locks,
  helpers

const
  ElemsPerNode = 100

type
  Node[T] = ptr object
    elems: array[ElemsPerNode, T]
    next: Node[T]
    first, last: int

  BlockingQueueObj*[T] = object
    head, tail: Node[T]
    size, maxSize: int
    lock*: Lock
    nonEmpty, nonFull: Cond
    closed: bool

  BlockingQueue*[T] = ref BlockingQueueObj[T]

template withLock(t, x: untyped) =
  acquire(t.lock)
  x
  release(t.lock)

template foreachNode[T](t: BlockingQueue[T], varName, code: untyped) =
  while (var varName = t.head; varName != nil):
    let next = varName.next
    code
    node = varName

proc dispose[T](t: BlockingQueue[T]) =
  withLock(t):
    t.foreachNode(node):
      deallocShared(node)
    t.head = nil
    t.tail = nil
  deinitLock t.lock

proc newBlockingQueue*[T](maxSize: int): BlockingQueue[T] =
  new(result) # TODO - finalizer: dispose[T])
  result.head = nil
  result.tail = nil
  result.size = 0
  result.maxSize = maxSize
  initLock result.lock
  initCond result.nonEmpty
  initCond result.nonFull

# should be called with lock
proc `$`*[T](this: BlockingQueue[T]): string =
  result = "BlockingQueue("
  result = result & addressRef(this) & ", "
  result = result & "head=" & addressObj(this.head[])
  result = result & ", tail=" & addressObj(this.tail[])
  result = result & ", size=" & $this.size
  result = result & ", maxSize=" & $this.maxSize
  this.foreachNode(node):
    result = result & ", node#" & addressObj(node[]) & "("
    result = result & "first=" & $node.first
    result = result & ",last=" & $node.last & ")"
  result = result & ")"

proc pop*[T](this: BlockingQueue[T]): Option[T] =
  withLock(this):
    var found = false
    template head: Node[T] = this.head
    template tail: Node[T] = this.tail
    template first: int = head.first
    template last: int = head.last
    while not found:
      if head != nil and first < last:
        found = true
        result = some(head.elems[first])
        inc(first)
        dec(this.size)
        if first == last and tail != head:
          let delete = head
          head = head.next
          deallocShared(delete)
      elif this.closed:
        found = true
        result = none(T)
      else:
        this.nonEmpty.wait(this.lock)

    if result.isSome:
      this.nonfull.signal()

iterator items*[T](this: BlockingQueue[T]): int =
  var x = this.pop()
  while x.isSome:
    yield x.get
    x = this.pop()

proc push*[T](this: BlockingQueue[T]; y: T): void =
  withLock(this):
    if this.closed:
      raise newException(Defect, "Cannot push to a closed BlockingQueue")
    while this.size >= this.maxSize and not this.closed:
      this.nonFull.wait(this.lock)
    if this.closed:
      raise newException(Defect, "Cannot push to a closed BlockingQueue")

    var node = this.tail
    if node == nil or (node.first == 0 and node.last == ElemsPerNode):
      node = cast[type node](allocShared0(sizeof(node[])))
      node.next = nil
      node.first = 0
      node.last = 0
      if this.tail != nil: this.tail.next = node
      this.tail = node
      if this.head == nil: this.head = node
    if node.last < ElemsPerNode:
      node.elems[node.last] = y
      inc(node.last)
    elif node.first > 0:
      dec(node.first)
      node.elems[node.first] = y
    else:
      raise newException(Defect, "WTF!")
    inc(this.size)
    this.nonEmpty.signal()

proc toSeq*[T](buf: BlockingQueue[T]): seq[T] =
  result = newSeq[T]()
  for x in buf.items:
    result.add(x)

proc close*[T](this: BlockingQueue[T]): void =
  withLock(this):
    this.closed = true
    this.nonEmpty.signal()
    this.nonFull.signal()
