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
There are example assembler files in `examples/`.


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
