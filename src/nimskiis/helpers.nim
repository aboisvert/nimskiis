
proc asRef*[T](p: ptr T): ref T {.inline.} =
  cast[ref T](p)

template allocT*(T: typedesc): ptr T =
  cast[ptr T](allocShared0(sizeof(T)))

template addressObj*(p: untyped): string =
  "0x" & $cast[int](addr(p))

template addressRef*(r: untyped): string =
  "0x" & $cast[int](r)

template addressPtr*(p: ptr): string =
  "0x" & $cast[int](p)

template debug*[T](s: string, p: ref T) =
  echo "Thread " & $getThreadId() & " - " & s & " - " & addressRef(p)

# Nim reserves the right to use pointers when you pass objects by value to a proc.
# This is an implementation detail of the compiler

