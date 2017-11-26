import locks

{.push stackTrace:off.}

type
  Counter* = ref object
    value: int
    maxValue: int
    lock: Lock
    maxValueReached: Cond
  
proc newCounter*(maxValue: int): Counter =
  new(result)
  result.value = 0
  result.maxValue = maxValue
  initLock(result.lock)
  initCond(result.maxValueReached)

proc dispose*(this: Counter): void =
  deinitLock(this.lock)
  deinitCond(this.maxValueReached)
  
proc await*(this: Counter) =
  acquire(this.lock)
  if this.value < this.maxValue:
    wait(this.maxValueReached, this.lock)
  release(this.lock)

proc inc*(this: Counter, n = 1): int {.discardable.} =
  acquire(this.lock)
  inc(this.value, n)
  result = this.value
  release(this.lock)
  if result >= this.maxValue:
    signal(this.maxValueReached)

{.pop.}