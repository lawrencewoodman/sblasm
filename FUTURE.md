# Future Features

* With string maps should 0-stringAddr become 0-?-x, where x is the offset

* Could use # as sugar to support a constant, where number is put into an address and the #constant is replaced with a pointer to it.

* Could use * as sugar to support indirect addressing? May not be a good idea because couldn't easily increment.  Also could conflict with pointer arithmetic. Perhaps use [] instead.

* Support conditional assembly .ifdef, .ifzero, if nzero, etc
