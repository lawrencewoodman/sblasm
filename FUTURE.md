# Future Features

* With string maps should 0-stringAddr become 0-?-x, where x is the offset

* Could use * as sugar to support indirect addressing? May not be a good idea because couldn't easily increment.  Also could conflict with pointer arithmetic. Perhaps use [] instead.  Maybe @ as shouldn't conflict.

* Support conditional assembly .ifdef/.ifexists, .ifzero, .ifnzero, etc

* Create an object format to allow linking pre-assembled files

* Add .alloc direcetive to allocate a number of words

* Have .cword .cascii as constants which can't be altered
  - or .const/.endconst to define blocks of constants
  - alternatively .var/.endvar to mutable variables
  - same with .selfm/.endselfm to define areas allowed
    to be self-modified

* Have .asciin to indicate a string preceeded by a word containing the
  number of characters in the string

* Mention creating single file with tekyll in README.md

* Create sble token instead of using id

* Put macro names in symbol table


## Configuration

* Be able to configure what \n characters to use for
  cross compilation:  .config slash_n 10

* Be able to specify that strings are made uppercase for cross
  compilation:   .config string_upcase true


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


* Find a way to allow something like the following work
  ; Create a zero-terminated string with a newline at the end
  .macro      arch::asciinlz str
              .ascii str
              arch::NLZ
  .endm


* Be able to pass a macro name into a macro
  .macro     runTwice mn
             mn
             mn
  .endm


## Document
* Valid labels and IDs
* Aiming for least surprise - little 'magic'
* Only implement what is actually used - YAGNI
* How macros are actually compiled not just expanded


## .equ Assembler Directive

* Should rename to .const to differentiate from a mutable variable?
* Support expressions to allow
  str:   .ascii  "hello how are you"
  .equ   strLen $-str

## Include

* Need an include path list
  - Should it include current path or should that always be the fist path
    to try.

* Should investigate a .require directive

* Have -rename switch on .include to allow renaming prefixes
  in the file to something else.  This is top stop name clashes with
  other namespaces.  Do this around the ????:: convention.
