import helpers, std/locks
import std/sets


when defined(debugSharedPtr):
  var debugSet: HashSet[pointer]
  var debugLock: Lock

  initLock(debugLock)
  debugSet = initHashSet[pointer]()

type
  Destructor*[T] = proc (this: var T): void {.nimcall.}

  SharedContent[T] = object
    value: ptr T
    lock: Lock
    references: int
    destructor: Destructor[T]

  SharedPtr*[T] = object
    ## Shared ownership reference counting pointer
    content: ptr SharedContent[T]

template getStack(): string =
  let stack = getStackTraceEntries()
  if stack.len >= 4:
    let s = stack[^4]
    $s.filename & ":" & $s.line
  else:
    $stack

proc `$`*[T](this: SharedContent[T]): string =
  if this.value == nil: "(value=nil)"
  else: "(value=" & $this.value[] &
       ", references=" & $this.references &
       ", ptr=" & addressPtr(this.value) & ")"

template debugEnabled0(body: untyped) =
  when defined(debugSharedPtr):
    body
  else:
    discard

template debugEnabled1[T](p: SharedPtr[T], body: untyped) =
  when defined(debugSharedPtr):
    {.gcsafe.}:
      if not p.isNil:
        acquire(debugLock)
        if debugSet.contains(p.content.value):
          body
        release(debugLock)
  else:
    discard

template debugSharedPtr*[T](this: SharedPtr[T]) =
  when defined(debugSharedPtr):
    acquire(debugLock)
    debugSet.incl(this.content.value)
    release(debugLock)
  else:
    discard

proc `=destroy`*[T](this: var SharedPtr[T]) =
  #when defined(debugSharedPtr):
    #if this.content != nil:
    #  echo "=destroy() called ", $this
    #  echo getStack()
  let content = this.content
  if content != nil:
    var destroyed = false
    acquire(content.lock)
    dec(content.references)
    if content.references <= 0:
      debugEnabled1(this):
        echo "=destroy() destroy ", $content[]
        echo getStack()
      destroyed = true
      this.content = nil
    else:
      debugEnabled1(this):
        echo "decremented(references) ", $content[]
        echo getStack()
    release(content.lock)
    if destroyed:
      content.destructor(content.value[])
      deallocShared(content.value)
      deinitLock(content.lock)
      deallocShared(content)


proc `=copy`*[T](dest: var SharedPtr[T], src: SharedPtr[T]) =
  if dest.content == src.content:
    # do nothing for self-assignments
    return

  debugEnabled1(src):
    var srcStr = "nil"
    var destStr = "nil"
    if src.content != nil: srcStr = $src.content[]
    if dest.content != nil: destStr = $dest.content[]
    echo "=copy ", srcStr, " to ", destStr
  if src.content != nil:
    withLock src.content.lock:
      inc(src.content.references)
      debugEnabled1(src):
        echo "incremented(references) ", $src.content[]
  `=destroy`(dest)
  dest.content = src.content
  debugEnabled1(src):
    echo "=copy  done."

proc `=sink`*[T](dest: var SharedPtr[T]; src: SharedPtr[T]) =
  debugEnabled1(src):
    var srcStr = "nil"
    var destStr = "nil"
    if src.content != nil: srcStr = $src.content[]
    if dest.content != nil: destStr = $dest.content[]
    echo "=sink ", srcStr, " to ", destStr
  `=destroy`(dest)
  wasMoved(dest)
  dest.content = src.content
  debugEnabled1(src):
    echo "=sink done."

proc initSharedPtr*[T](value: ptr T, destructor: Destructor[T]): SharedPtr[T] =
  result.content = allocShared0T(SharedContent[T])
  let this = result.content
  this.value = value
  this.references = 0
  initLock(this.lock)
  debugEnabled0:
    echo "init ", addressPtr(value), ": ", typeof(value[])
  this.destructor = destructor

proc isNil*[T](this: SharedPtr[T]): bool {.inline.} =
  this.content == nil

proc `danger[]`*[T](this: SharedPtr[T]): var T {.inline.} =
  let this = this.content
  when compileOption("boundChecks"):
    doAssert(this != nil, "deferencing nil shared pointer")
  withLock this.lock:
    result = this.value[]

proc asPtr*[T](this: SharedPtr[T]): ptr T {.inline, gcsafe.} =
  let this = this.content
  when compileOption("boundChecks"):
    doAssert(this != nil, "deferencing nil shared pointer")
  withLock this.lock:
    result = this.value

proc `$`*[T](this: SharedPtr[T]): string =
  let this = this.content
  if this == nil: "SharedPtr[" & $T & "](nil)"
  else: "SharedPtr[" & $T & "](" & $this[] & ")"

proc noopDestructor*[T](t: typedesc[T]): Destructor[T] =
  result = proc (this: var T): void {.nimcall.} =
    discard

proc unbox*[T](this: SharedPtr[T]): T {.inline, gcsafe.} =
  let this = this.content
  when compileOption("boundChecks"):
    doAssert(this != nil, "deferencing nil shared pointer")
  withLock this.lock:
    result = this.value[]

# === SharedString

type SharedString* = SharedPtr[UncheckedArray[char]]

proc `$`*(this: UncheckedArray[char]): string =
  "UncheckedArray[char](\"" &  $(cast[cstring](this)) & "\")"

proc `$`*(s: SharedString): string =
  var carray: ptr UncheckedArray[char] = s.asPtr
  $(cast[cstring](carray))

proc sharedString*(cstr: cstring): SharedString =
  let len = cstr.len
  #echo "copy ", cstr
  #echo "len ", len
  #if len != 1:
  #  echo "copy ", cstr
  #  echo "len ", len

  let carray = cast[ptr UncheckedArray[char]](allocShared0(len + 1))
  copyMem(carray, cstr, len + 1)
  initSharedPtr(carray, noopDestructor(UncheckedArray[char]))
