# Future Features

* With string maps should 0-stringAddr become 0-?-x, where x is the offset

* Could use # as sugar to support a constant, where number is put into an address and the #constant is replaced with a pointer to it.  Or should constants such as OUT and HALT be prefixed with #

* Could use * as sugar to support indirect addressing? May not be a good idea because couldn't easily increment.  Also could conflict with pointer arithmetic. Perhaps use [] instead.  Maybe @ as shouldn't conflict.

* Support conditional assembly .ifdef, .ifzero, if nzero, etc

* Create an object format to allow linking pre-assembled files

* Add .alloc direcetive to allocate a number of words

* Prepend error_ to all tests/fixtures/ error files

* Create separate lexer which records line numbers properly


## Include

* Need to say what filename is being processed for errors

* Need to improve listing handling of filenames

* Need an include path list

* Have a way of including a file, but how will this effect listings
  - and how will name resolution work - can prepend?
  - Could do this with a require

* Have -rename switch on .include to allow renaming prefixes
  in the file to something else.  This is top stop name clashes with
  other namespaces.  Do this around the ????:: convention.
