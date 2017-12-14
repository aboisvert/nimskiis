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
