# Future Features

* With string maps should 0-stringAddr become 0-?-x, where x is the offset

* Could use # as sugar to support a constant, where number is put into an address and the #constant is replaced with a pointer to it.  Or should constants such as OUT and HALT be prefixed with #

* Could use * as sugar to support indirect addressing? May not be a good idea because couldn't easily increment.  Also could conflict with pointer arithmetic. Perhaps use [] instead.  Maybe @ as shouldn't conflict.

* Support conditional assembly .ifdef/.ifexists, .ifzero, .ifnzero, etc

* Create an object format to allow linking pre-assembled files

* Add .alloc direcetive to allocate a number of words

## Macros

* NASM has some useful ideas
  - https://nasm.us/doc/nasmdoc4.html
* Should macro names be allowed to be the same as labels and constants?
* Allow strings and literal values to be passed to macro


        writefile [filehandle],"hello, world",13,10

NASM allows you to define the last parameter of a macro to be greedy, meaning that if you invoke the macro with more parameters than it expects, all the spare parameters get lumped into the last defined one along with the separating commas. So if you code:

%macro  writefile 2+

        jmp     %%endstr
  %%str:        db      %2
  %%endstr:
        mov     dx,%%str
        mov     cx,%%endstr-%%str
        mov     bx,%1
        mov     ah,0x40
        int     0x21

%endmacro

* Support Variable Length macros

* Support numbered parameters: %1, %2, etc
  %0 is number of parameters
  - Allow querying of the token type of the arguments
  - support .rotate on this to make it easy to move
    through parameters

* Could specify type of variables using something like
  .macro     printStr str:string


## Document
* Valid labels and IDs
* Aiming for least surprise - little 'magic'
* Only implement what is actually used - YAGNI
* How macros are actually compiled not just expanded

## Errors

* Test line numbers of errors within macros
* Perhaps add macro name to error

## .equ Assembler Directive

* Should rename to .const to differentiate from a mutable variable?
* Support expressions to allow
  str:   .ascii  "hello how are you"
  .equ   strLen $-str

## Include

* Need to say what filename is being processed for errors

* Need to improve listing handling of filenames

* Need an include path list
  - Should it include current path or should that always be the fist path
    to try.

* Have a way of including a file, but how will this effect listings
  - and how will name resolution work - can prepend?
  - Could do this with a require

* Have -rename switch on .include to allow renaming prefixes
  in the file to something else.  This is top stop name clashes with
  other namespaces.  Do this around the ????:: convention.
