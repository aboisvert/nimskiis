import sharedptr, std/locks, helpers

type
  Content = object
    lock: Lock
    value: int # TODO {.guard: lock.}

  AtomicInteger* = SharedPtr[Content]

proc destructor(this: var Content) =
  deinitLock(this.lock)

proc `=destroy`[T](this: var Content) =
  destructor(this)

proc newAtomicInteger*(value: int = 0): AtomicInteger =
  let content = allocShared0T(Content)
  initLock content.lock
  content.value = value
  result = initSharedPtr[Content](content, destructor)

proc incrementAndGet*(this: AtomicInteger, inc: int = 1): int =
  let this = this.asPtr
  withLock this.lock:
    this.value += inc
    result = this.value

proc inc*(this: AtomicInteger, inc: int = 1): int {.discardable.} =
  this.incrementAndGet(inc)

proc get*(this: AtomicInteger): int =
  let this = this.asPtr
  withLock this.lock:
    result = this.value

proc `$`*(this: AtomicInteger): string =
  let this = this.asPtr
  withLock this.lock:
    result = "AtomicInteger(" & $this.value & ")"
