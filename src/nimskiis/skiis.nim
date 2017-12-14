import
  options,
  locks,
  os

export
  options,
  locks

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
  SkiisObj[T] = object
    methods*: tuple[  # see below for method descriptions
      next: proc(): Option[T],
      take: proc(n: int): seq[T],
      dispose: proc(): void
    ]
  Skiis*[T] = ref SkiisObj[T]
  SkiisPtr*[T] = ptr SkiisObj[T]

  SkiisContext* = object
    parallelism*: int
    queue*: int
    batch*: int

# Get the next element
proc next*[T](skiis: Skiis[T]): Option[T] =
  skiis.methods.next()

# Take `n` elements at a time (for efficiency)
proc take*[T](skiis: Skiis[T], n: int): seq[T] =
  skiis.methods.take(n)

# Dispose of this Skiis' resrouces
proc dispose*[T](skiis: Skiis[T]) =
  skiis.methods.dispose()

proc genericTake*[T](next: proc (): Option[T], n: int): seq[T] =
  if n <= 0: return newSeq[T]()
  result = newSeqOfCap[T](n)
  var n = n
  var x = next()
  while (x.isSome):
    result.add(x.get)
    dec n
    if n == 0: return
    x = next()

template foreach*[T](skiis: Skiis[T], name, body: untyped) =
  var next = skiis.next()
  while (next.isSome):
    let name = next.get
    body
    next = skiis.next()

proc toSeq*[T](skiis: Skiis[T]): seq[T] =
  result = newSeq[T]()
  skiis.foreach(n):
    result.add(n)
