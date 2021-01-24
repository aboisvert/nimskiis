import locks, helpers

#{.push stackTrace:off.}

type
  Counter* = object
    alive: bool
    value: int
    maxValue: int
    lock: Lock
    maxValueReached: Cond

proc dispose*(this: var Counter) =
  if this.alive:
    this.alive = false
    deinitLock(this.lock)
    deinitCond(this.maxValueReached)

proc `=destroy`*(this: var Counter) =
  dispose(this)

proc init(this: var Counter, maxValue: int) =
  this.alive = true
  this.value = 0
  this.maxValue = maxValue
  initLock(this.lock)
  initCond(this.maxValueReached)

proc newCounterPtr*(maxValue: int): ptr Counter =
  result = allocShared0T(Counter)
  init(result[], maxValue)

proc newCounter*(maxValue: int): ref Counter =
  new(result)
  init(result[], maxValue)

proc await*(this: var Counter) =
  acquire(this.lock)
  if this.value < this.maxValue:
    this.maxValueReached.wait(this.lock)
    this.maxValueReached.signal() # chained broadcast
  release(this.lock)

proc inc*(this: var Counter, n = 1): int {.discardable.} =
  acquire(this.lock)
  inc(this.value, n)
  result = this.value
  release(this.lock)
  if result >= this.maxValue:
    this.maxValueReached.signal()

#{.pop.}