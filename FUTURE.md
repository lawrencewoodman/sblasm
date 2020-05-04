# Future Features

* With string maps should 0-stringAddr become 0-?-x, where x is the offset

* Could use # as sugar to support a constant, where number is put into an address and the #constant is replaced with a pointer to it.

* Could use * as sugar to support indirect addressing? May not be a good idea because couldn't easily increment.  Also could conflict with pointer arithmetic. Perhaps use [] instead.  Maybe @ as shouldn't conflict.

* Support conditional assembly .ifdef, .ifzero, if nzero, etc

* Have a way of including a file, but how will this effect listings
  - and how will name resolution work - can prepend?
  - Could do this with a require

* Create an object format to allow linking pre-assembled files

* Add .alloc direcetive to allocate a number of words
