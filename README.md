sblasm
======

[![Build Status](https://travis-ci.org/lawrencewoodman/sblasm.svg?branch=master)](https://travis-ci.org/lawrencewoodman/sblasm)

A SUBLEQ macro assembler

Usage
-----
The assembler takes an assembly source filename, assembles it and
outputs the code as ascii numbers.

    Usage: main.tcl [OPTION]... filename
    Assemble SUBLEQ assembly from filename

    Arguments:
      -l filename      Output a listing to listing to filename
      -h               Display this help and exit
      --               Mark the end of switches

Examples
--------
There are number of example assembler files in `examples/`.

### FizzBuzz
Here is an example of a [FizzBuzz](https://en.wikipedia.org/wiki/Fizz_buzz) program.  The file [fizzbuzz.asq](https://github.com/lawrencewoodman/sblasm/blob/master/examples/fizzbuzz.asq) is in `examples/`.  It shows the following:

* Comments beginning with `;`
* Assembler directives.  Here: `.equ`, `.include`, `.word`, `.asciiz`, etc.
* The single assembler instruction `sble`
* Macros being called.  In this example: `inc`, `copy`, `mod`, `io::printStr`, etc.
* Labels ending with `:`

<br /><br />

```
; Fizz buzz program
;
; Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
; Licensed under a BSD 0-Clause licence. Please see 0BSD_LICENCE.md for details.

.equ        OUT -1
.equ        HALT -1

.include    "standard.asq"
.include    "io.asq"


;========================================
;           Start
;========================================
            sble  z z main


;========================================
;           Data Storage
;========================================
count:      .word 30                 ; The number to count up to
n:          .word 1                  ; The number being counted
nC:         .word 0
fizzbuzzS:  .asciiz "FizzBuzz"
fizzS:      .asciiz "Fizz"
buzzS:      .asciiz "Buzz"
spaceCh:    .ascii " "
three:      .word 3
five:       .word 5
fifteen:    .word 15


;========================================
;           Main
;========================================
main:       inc count
loop:       sble  one count done     ; if count <= 0

            copy  n nC
            mod   fifteen nC
            sble  z nC fizzbuzz

            copy  n nC
            mod   three nC
            sble  z nC fizz

            copy  n nC
            mod   five nC
            sble  z nC buzz

            io::printInt16 n
            jump  nextN

fizzbuzz:   io::printStr fizzbuzzS
            jump  nextN
fizz:       io::printStr fizzS
            jump  nextN
buzz:       io::printStr buzzS
            jump  nextN

nextN:      inc   n
            sble  spaceCh OUT
            jump  loop

done:       sble  z z HALT
```


Requirements
------------
*  Tcl 8.6+
*  Tcllib


Vendor Requirements
-------------------
The following requirements are located in the `vendor/` directory.

*  [xproc](https://github.com/lawrencewoodman/xproc_tcl)


Testing
-------
There is a testsuite in `tests/`.  To run it:

    $ tclsh tests/all.tcl


Contributing
------------
I would love contributions to improve this project.  To do so easily I ask the following:

  * Please put your changes in a separate branch to ease integration.
  * For new code please add tests to prove that it works.
  * Update [CHANGELOG.md](https://github.com/lawrencewoodman/sblasm/blob/master/CHANGELOG.md).
  * Make a pull request to the [repo](https://github.com/lawrencewoodman/sblasm) on github.

If you find a bug, please report it at the project's [issues tracker](https://github.com/lawrencewoodman/sblasm/issues) also on github.


Licence
-------
Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>

This software is licensed under an MIT Licence.  Please see the file, [LICENCE.md](https://github.com/lawrencewoodman/sblasm/blob/master/LICENCE.md), for details.
