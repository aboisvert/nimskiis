
# Concurrent (thread-safe) unbounded buffer.
#
# Basically a multable seq, with push() and pop() semantics.
#
# NOTE:  This is an unordered collection.  push() may not append at the end of the buffer.
#        In that sense, Buffer is more like an unordered bag.
#
# push() appends "towards" the end of the bag
# pop() removes the current first element of the bag.

import
  std/options,
  std/locks,
  std/sets,
  helpers

const
  ElemsPerNode = 100

type
  Node[T] = ptr object
    elems: array[ElemsPerNode, T]
    next: Node[T]
    first, last: int

  Buffer*[T] = object
    head, tail: Node[T]
    size: int
    lock*: Lock

template withLock(t, x: untyped) =
  acquire(t.lock)
  x
  release(t.lock)

template foreachNode[T](b: Buffer[T], varName, code: untyped) =
  var varName = b.head
  while varName != nil:
    let next = varName.next # save `next` since node could be deallocated
    code
    varName = next

proc disposeBuffer*[T](b: var Buffer[T]) =
  #echo "disposeBuffer"
  withLock(b):
    b.foreachNode(node): deallocShared(node)
    b.head = nil
    b.tail = nil
  deinitLock b.lock

proc `=destroy`*[T](b: var Buffer[T]) =
  echo "destroy call on Buffer"
  disposeBuffer(b)

proc newBufferPtr*[T](): ptr Buffer[T] =
  result = allocShared0T(Buffer[T])
  initLock result.lock
  result.head = nil
  result.tail = nil

proc initBuffer*[T](): Buffer[T] =
  initLock result.lock
  result.head = nil
  result.tail = nil

proc pop*[T](this: var Buffer[T]): Option[T] =
  withLock(this):
    template head: Node[T] = this.head
    template tail: Node[T] = this.tail
    template first: int = head.first
    template last: int = head.last
    if head != nil and first < last:
      result = some(head.elems[first])
      dec(this.size)
      inc(first)
      if first == last and tail != head:
        let delete = head
        head = head.next
        deallocShared(delete)
    else:
      result = none(T)

iterator popItems*[T](this: Buffer[T]): T =
  var x = this.pop()
  while x.isSome:
    yield x.get
    x = this.pop()

# TODO:  this shouldn't pop() items!  should be read-only
iterator items*[T](this: var Buffer[T]): T =
  var x = this.pop()
  while x.isSome:
    yield x.get
    x = this.pop()


proc push*[T](this: var Buffer[T]; y: sink T): void =
  withLock(this):
    inc(this.size)
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
      discard # ???

proc size*[T](this: var Buffer[T]): int {.inline.} =
  withLock(this):
    result = this.size

proc toSeq*[T](buf: var Buffer[T]): seq[T] =
  result = newSeq[T]()
  for x in buf.items:
    result.add(x)

proc toHashSet*[T](buf: var Buffer[T]): HashSet[T] =
  result = initHashSet[T]()
  for x in buf.items:
    result.incl(x)

proc `$`*[T](this: var Buffer[T]): string =
  result = "Buffer("
  template p(x: untyped): string = $cast[int](x)
  withLock(this.lock):
    result = result & "head=" & p(this.head)
    result = result & ", tail=" & p(this.tail)
    this.foreachNode(node):
      result = result & ", node#" & p(node) & "("
      result = result & "first=" & $node.first
      result = result & ",last=" & $node.last & ")"
  result = result & ")"