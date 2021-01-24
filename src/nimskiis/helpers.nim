import locks

proc asRef*[T](p: ptr T): ref T {.inline.} =
  cast[ref T](p)

template allocShared0T*(T: typedesc): ptr T =
  cast[ptr T](allocShared0(sizeof(T)))

template addressObj*(p: untyped): string =
  "0x" & $cast[int](addr(p))

template addressRef*(r: untyped): string =
  "0x" & $cast[int](r)

template addressPtr*(p: ptr): string =
  "0x" & $cast[int](p)

template lockInitWith*(a: var Lock, body: untyped) =
  initLock(a)
  {.locks: [a].}:
    body

template debug*[T](s: string, p: ref T) =
  #echo "Thread " & $getThreadId() & " - " & s & " - " & addressRef(p)
  discard 1

# Identity function
proc identity*[T](t: T): T =
  t

iterator grouped*[T](s: seq[T], size: int): seq[T] =
  var group: seq[T] = newSeqOfCap[T](size)
  if size <= 0: return
  for x in s:
    group.add(x)
    if group.len >= size:
      yield group
      group = newSeqOfCap[T](size)

proc grouped*[T](s: seq[T], size: int): seq[seq[T]] =
  var group: seq[T] = newSeqOfCap[T](size)
  if size <= 0: return
  for x in s:
    group.add x
    if group.len >= size:
      result.add group
      group = newSeqOfCap[T](size)
