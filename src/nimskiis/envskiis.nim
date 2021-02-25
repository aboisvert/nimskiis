import skiis, helpers, sharedptr

type
  EnvSkiis[T; ENV] = object of SkiisObj[ValueEnv[T, ENV]]
    input: Skiis[T]
    env: SharedPtr[ENV]

proc EnvSkiis_destructor[T; ENV](this: var EnvSkiis[T, ENV]) =
  `=destroy`(this.input)
  #`=destroy`(this.env)

proc `=destroy`[T; ENV](this: var EnvSkiis[T, ENV]) =
  EnvSkiis_destructor(this)

proc next*[T; ENV](this: ptr EnvSkiis[T, ENV]): Option[ValueEnv[T, ENV]] =
  let next: Option[T] = this.input.next()
  if next.isSome: some(ValueEnv[T, ENV](value: next.get, env: this.env))
  else: none(ValueEnv[T, ENV])

proc EnvSkiis_next[T; ENV](this: ptr SkiisObj[ValueEnv[T, ENV]]): Option[ValueEnv[T, ENV]] =
  type U = ValueEnv[T, ENV]
  let this: ptr EnvSkiis[T, ENV] = downcast[U, EnvSkiis[T, ENV]](this)
  this.next()

proc initEnvSkiis*[T; ENV](input: Skiis[T], env: SharedPtr[ENV]): Skiis[ValueEnv[T, ENV]] =
  let this = allocShared0T(EnvSkiis[T, ENV])
  this.nextMethod = EnvSkiis_next[T, ENV]
  this.takeMethod = defaultTake[ValueEnv[T, ENV]]
  this.input = input
  this.env = env
  result = asSharedPtr[ValueEnv[T, ENV], EnvSkiis[T, ENV]](this, EnvSkiis_destructor[T, ENV])
