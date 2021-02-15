import
  std/options,
  std/os,
  sharedptr

export options

# Base Skiis definitions.
#
# Think "Parallel Skiis".
#
# Skiis are inspired by the Staged Event-Driven Architecture (SEDA)
# https://en.wikipedia.org/wiki/Staged_event-driven_architecture
#
# The rough idea is that complex computation/processing can be decomposed into a set
# of parallel-processing stages connected by (bounded, blocking) queues.
#
# A typical stage is:
#
#      +--------------+        +-------------+       +-------------+
#      |    Input     |  ===>  |  Function   |  ===> |   Output    |
#      +--------------+        +-------------+       +-------------|
#         Queue from             Executed by          Queue towards
#       previous stage           `n` parallel         next stage
#                                threads
#
# By performing admission control on each event queue, each stage can be well-conditioned
# to load, preventing resources (used by stages) from being overcommitted when demand exceeds
# service capacity.
#
# Skiis are thread-safe and resource-aware iterator-like collections.
# All subclasses (implementations satisfying Skiis interface) *must* be thread-safe.
#
# Since Skiis's are meant to be used concurrently, their specific ordering is generally undefined.
# However, the general assumption is that Skiis operate in a (non-strict) FIFO manner.
#
# The regular map(), flatMap(), filter(), etc. functions are lazy and meant to be used for
# stream-fusion.   They are stacked ("fused") together until a strict (as in non-lazy)
# operation is performed.
#
# The parallel-execution functions are all strict and immediately spawn `n` parallel tasks
# to a thread pool.  Parallel functions share the `parXXX` naming convention: parMap(),
# parFlatMap(), parFilter(), etc.
#

#
# (To avoid circular dependencies, operations on Skiis are defined in skiisops.nim.)
#

type
  NextMethod*[T] = proc (this: ptr SkiisObj[T]): Option[T] {.nimcall.}
  TakeMethod*[T] = proc (this: ptr SkiisObj[T], n: int): seq[T] {.nimcall.}

  SkiisObj*[T] = object of RootObj
    debugName*: string
    nextMethod*: NextMethod[T]
    takeMethod*: TakeMethod[T]

  Skiis*[T] = SharedPtr[SkiisObj[T]]

  SkiisContext* = object
    parallelism*: int
    queue*: int
    batch*: int

  ValueEnv*[T; ENV] = object
    value*: T
    env*: SharedPtr[ENV]

proc `$`*[T](this: SkiisObj[T]): string =
  if this.debugName.len > 0: this.debugName
  else: "SkiisObj[T](?)"

template asSharedPtr*[T; OBJ: SkiisObj[T]](
  skiisObj: ptr OBJ,
  destructor: Destructor[OBJ]
): Skiis[T] =
  cast[Skiis[T]](initSharedPtr[OBJ](skiisObj, destructor))

proc downcast*[T; OBJ: SkiisObj[T]](this: ptr SkiisObj[T]): ptr OBJ =
  cast[ptr OBJ](this)

# Get the next element
proc next*[T](skiis: Skiis[T]): Option[T] {.inline.} =
  let skiisObj = skiis.asPtr
  let `method` = skiisObj.nextMethod
  `method`(skiisObj)

# Take `n` elements at a time (for efficiency)
#
# This batch-oriented version of `next` allows client code to
# to amortize costs associated with locking the underlying
# data structure over a number of items.
#
# Skiis implementation should override this (virtual) method
# and optimize their `take` logic to minimize locking overhead
# for any number of items requested.
proc take*[T](skiis: Skiis[T], n: int): seq[T] {.inline} =
  let skiisObj = skiis.asPtr
  let `method` = skiisObj.takeMethod
  `method`(skiisObj, n)

# Default implementation of `take`.
#
# Skiis implementations should provide behavior
# equivalent to this proc.
proc defaultTake*[T](skiis: ptr SkiisObj[T], n: int): seq[T] =
  if n <= 0: return newSeq[T]()
  result = newSeqOfCap[T](n)
  let next = skiis.nextMethod
  var n = n
  var x = next(skiis)
  while (x.isSome):
    result.add(x.get)
    dec n
    if n == 0: return
    x = next(skiis)

template foreach*[T](skiis: Skiis[T], name, body: untyped) =
  var next = skiis.next()
  while (next.isSome):
    let name = next.get
    body
    next = skiis.next()

template foldl*[T](skiis: Skiis[T], accName, elemName, body: untyped): T =
  let first: Option[T] = skiis.next()
  assert first.isSome, "Can't fold empty sequences"
  var accName: T = first.get
  var next: Option[T] = skiis.next()
  while (next.isSome):
    let elemName = next.get
    accName = body
    next = skiis.next()
  accName

proc toSeq*[T](skiis: Skiis[T]): seq[T] =
  result = newSeq[T]()
  skiis.foreach(n):
    result.add(n)
