#! /usr/bin/env bash
# A script to run some of the examples

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OLDDIR=`pwd`

cd $SCRIPTPATH

SBLASM=$SCRIPTPATH/../main.tcl
SBLE_VM=$SCRIPTPATH/../bin/sble_vm.tcl


echo
echo
echo "standard.test.asq"
echo "================="
echo

tclsh $SBLASM standard.test.asq > standard.test.sq
tclsh $SBLE_VM standard.test.sq


echo
echo
echo "io.test.asq"
echo "==========="
echo

tclsh $SBLASM io.test.asq > io.test.sq
tclsh $SBLE_VM io.test.sq


echo
echo
echo "test.test.asq"
echo "============="
echo

tclsh $SBLASM test.test.asq > test.test.sq
tclsh $SBLE_VM test.test.sq


echo
echo
echo "msg_macros.asq"
echo "=============="
echo

tclsh $SBLASM msg_macros.asq > msg_macros.sq
tclsh $SBLE_VM msg_macros.sq


echo "fizzbuzz.asq"
echo "============"
echo

tclsh $SBLASM fizzbuzz.asq > fizzbuzz.sq
tclsh $SBLE_VM -trace fizzbuzz.sq


cd $OLDDIR
