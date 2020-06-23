#! /usr/bin/env bash
# A script to run some of the examples

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OLDDIR=`pwd`

cd $SCRIPTPATH

SBLASM=$SCRIPTPATH/../main.tcl
SBLE_VM=$SCRIPTPATH/../bin/sble_vm.tcl

echo
echo
echo SETUP
echo =====
echo
echo -n Assembling example files...
printf "sble16.test standard.test io.test test.test msg_macros fizzbuzz" | xargs  -d " " -P 5 -n 1 -I _ tclsh $SBLASM -o _.sq _.asq
echo done


echo
echo
echo "sble16.test.asq"
echo "==============="
echo

tclsh $SBLE_VM -word 16 sble16.test.sq


echo
echo
echo "standard.test.asq"
echo "================="
echo

tclsh $SBLE_VM standard.test.sq


echo
echo
echo "io.test.asq"
echo "==========="
echo

tclsh $SBLE_VM io.test.sq


echo
echo
echo "test.test.asq"
echo "============="
echo

tclsh $SBLE_VM test.test.sq


echo
echo
echo "msg_macros.asq"
echo "=============="
echo

tclsh $SBLE_VM msg_macros.sq


echo
echo
echo "fizzbuzz.asq"
echo "============"
echo

tclsh $SBLE_VM fizzbuzz.sq


echo
echo
echo "FINISH"
echo "======"
echo
echo All done

cd $OLDDIR
