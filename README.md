Nim Skiis: Streaming + Parallel collection for Nim
==================================================

Think "Parallel Skiing"

Skiis are streaming / iterator-like collections that support both
"stream fusion" and parallel operations.

This is an experimental project to port the original Scala skiis library (https://github.com/aboisvert/skiis) to Nim.  It is a work in progress and much of the functionality of the original library has not yet been realized.

I am using this project as a way to better learn the Nim language, and hopefully will become an important building block for future projects I have in mind with Nim.

### Building ###

    # compile sources and produce library
    nimble lib

    # run tests
    nimble tests


### Target platform ###

* Currently tested on Nim 0.17.2.

### License ###

Nim-Skiis is is licensed under the terms of the Apache Software License v2.0.
<http://www.apache.org/licenses/LICENSE-2.0.html>

Code is copyright (C) Alex Boisvert, 2017 unless otherwise noted.

