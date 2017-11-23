
template addressObj*(p: untyped): string =
  "0x" & $cast[int](unsafeAddr(p))

template addressRef*(r: untyped): string =
  "0x" & $cast[int](r)

template addressPtr*(p: ptr): string =
  "0x" & $cast[int](p)

