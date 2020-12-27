
import
  options,
  locks

const
  ElemsPerNode = 100

type
  Node[T] = ptr object
    elems: array[ElemsPerNode, T]
    next: Node[T]
    last: int

  List*[T] = object
    head, tail: Node[T]

template foreachNode*[T](this: List[T], varName, code: untyped) =
  var varName = this.head
  while varName != nil:
    let next = varName.next # save `next` since node could be deallocated
    code
    varName = next

template foreach*[T](this: List[T], varName, code: untyped) =
  this.foreachNode(node):
    var i = 0
    while i < node.last:
      let varName = node.elems[i]
      code
      i += 1

proc newList*[T](xs: varargs[T]): List[T] =
  result.pushAll(xs)

proc disposeList*[T](this: var List[T]) =
  this.foreachNode(node): deallocShared(node)
  this.head = nil
  this.tail = nil

proc push*[T](this: var List[T]; y: T): void =
  var node = this.tail
  if node == nil or node.last == ElemsPerNode:
    node = cast[type node](allocShared0(sizeof(node[])))
    node.next = nil
    node.last = 0
    if this.tail != nil: this.tail.next = node
    this.tail = node
    if this.head == nil: this.head = node
  node.elems[node.last] = y
  inc(node.last)

proc pushAll*[T](this: var List[T]; xs: varargs[T]): void =
  var node = this.tail
  for x in xs:
    if node == nil or node.last == ElemsPerNode:
      node = cast[type node](allocShared0(sizeof(node[])))
      node.next = nil
      node.last = 0
      if this.tail != nil: this.tail.next = node
      this.tail = node
      if this.head == nil: this.head = node
    node.elems[node.last] = x
    inc(node.last)

proc toSeq*[T](this: List[T]): seq[T] =
  result = newSeq[T]()
  this.foreach(x):
    result.add(x)

proc `$`*[T](this: List[T]): string =
  result = "List("
  this.foreach(t):
    result = result & $t
  result = result & ")"