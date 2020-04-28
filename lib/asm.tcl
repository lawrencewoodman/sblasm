#! /usr/bin/env tclsh
#
# SUBLEQ assembler routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# Return {output listing errors}
xproc::proc assemble {src} {
  lassign [pass1 "Main" $src] \
      pass1Output constants labels pass1Listing errors
  if {[llength $errors] > 0} {
    return [list {} {} $errors]
  }
  lassign [pass2 $pass1Output $constants $labels] pass2Output pass2Listing
  lassign [pass3 $pass2Output] pass3Output pass3Listing
  set listing [list {*}$pass1Listing {*}$pass2Listing {*}$pass3Listing]
  return [list $pass3Output $listing {}]
}


# Return {output constants labels listing errors}
proc pass1 {srcName src {macros {}}} {
  set errors {}
  set codeListing {}
  set labels [dict create]
  set constants [dict create]
  set pos 0
  set result [list]
  set lineNum 0
  while {$lineNum < [llength $src]} {
    set line [lindex $src $lineNum]
    set linePos 0
    while {$linePos < [string length $line]} {
      set linePos [skipWhitespace $line $linePos]
      lassign [getWord $line $linePos] word wordEnd

      if {[isComment $word]} {
        set wordEnd [string length $line]
      } elseif {[isCommand $word]} {
        switch $word {
          .ascii {
            set start [skipWhitespace $line [expr {$wordEnd+1}]]
            try {
              lassign [getString $line $start] str charNums wordEnd
              if {[llength $charNums] > 0} {
                lappend codeListing [list $pos ascii \"$str\"]
                lappend result {*}$charNums
                incr pos [llength $charNums]
              }
            } on error {err} {
              lappend errors [makeError $lineNum $line $err]
              set wordEnd [string length $line]
            }
          }
          .equ {
            lassign [getWord $line [expr {$wordEnd+1}]] name wordEnd
            lassign [getWord $line [expr {$wordEnd+1}]] val wordEnd
            if {[dict exists $labels $name]} {
              lappend errors [makeError $lineNum $line "Name clash: $name"]
            } else {
              dict set constants $name $val
            }
          }
          .macro {
            set nextPos [expr {$wordEnd+1}]
            lassign [compileMacro $src $lineNum $nextPos $macros] \
                    macros lineNum macroListing macroErrors
            if {[llength $macroErrors] > 0} {
              set errors [list {*}$errors {*}$macroErrors]
            } else {
              lappend listing {*}$macroListing
            }
            set line [lindex $src $lineNum]
            set wordEnd [string length $line]
          }
          .word {
            while {1} {
              lassign [getWord $line [expr {$wordEnd+1}]] val wordEnd
              if {[isComment $val]} {
                set wordEnd [string length $line]
                break
              }
              if {$val eq ""} {break}
              lappend codeListing [list $pos word $val]
              lappend result $val
              incr pos
            }
          }
        }
      } elseif {[isDefineLabel $word]} {
        set name [string trimright $word :]
        if {[dict exists $constants $name]} {
          lappend errors [makeError $lineNum $line "Name clash: $name"]
        } else {
          dict set labels $name $pos
          lappend codeListing [list $pos label $word]
        }
      } elseif {[isSbleInstruction $word]} {
        try {
          lassign [getSbleInstruction $line [expr {$wordEnd+1}]] \
                  instruction wordEnd
          lappend codeListing [list $pos sble $instruction]
          lappend result {*}$instruction
          incr pos 3
        } on error {err} {
          lappend errors [makeError $lineNum $line $err]
          set wordEnd [string length $line]
        }
      } else {
        set name $word
        try {
          lassign [runMacro $name $line [expr {$wordEnd+1}] $macros] mArgs body
          lappend result {*}$body
          lappend codeListing [list $pos macro $name $mArgs]
          incr pos [llength $body]
        } on error {err} {
          lappend errors [makeError $lineNum $line $err]
        }
        set wordEnd [string length $line]
      }
      set linePos [expr {$wordEnd+1}]
    }
    incr lineNum
  }

  lappend listing "\nPass 1 - $srcName"
  lappend listing "[string repeat "=" [expr {[string length $srcName]+9}]]\n"
  if {[llength $constants] > 0} {
    lappend listing "Constants\n---------\n$constants\n"
  }
  lappend listing "Listing\n-------\n"
  lappend listing {*}[prettyFormatCodeListing $codeListing]
  lappend listing "\n"

  return [list $result $constants $labels $listing $errors]
}


proc makeError {lineNum line error} {
  incr lineNum
  return [dict create lineNum $lineNum line $line msg $error]
}


proc prettyFormatCodeListing {codeListing} {
  set formattedListing {}
  foreach entry $codeListing {
    lassign $entry pos type
    set vals [lrange $entry 2 end]
    if {$type eq "label"} {
      lappend formattedListing [format {%4i %s} $pos $vals]
    } elseif {$type eq "macro"} {
      lassign $vals name mArgs
      lappend formattedListing \
              [format {%4i %10s %-7s %s  %s} $pos "" $type $name $mArgs]
    } elseif {$type eq "sble"} {
      lassign [lindex $vals 0] a b c
      lappend formattedListing \
              [format {%4i %10s %-7s %s %s %s} $pos "" $type $a $b $c]

    } else {
      lappend formattedListing \
              [format {%4i %10s %-7s %s} $pos "" $type [lindex $vals 0]]
    }
  }
  return $formattedListing
}


xproc::proc calcLabelOffsets {pos labels} {
  return [dict map {name labelPos} $labels {
    set offset [expr {$labelPos-$pos}]
    format {$%+i} $offset
  }]
}


proc joinLabelsConstants {constants labels} {
  set res $labels
  dict for {c_k c_v} $constants {
    dict set res $c_k $c_v
  }
  return $res
}


xproc::proc pass2 {pass1Output constants labels} {
  lappend listing "Pass 2\n======\n"
  set pos 0
  set res [lmap x $pass1Output {
    if {[expr $pos % 5] == 0} {
      lappend listing [format "%4i  " $pos]
    }
    set newX $x
    if {![string is integer $x]} {
      set labelOffsets [calcLabelOffsets $pos $labels]
      set names [joinLabelsConstants $constants $labelOffsets]
      set sortedNames [sortLabelsByLength $names]
      set newX [string map $sortedNames $x]
    }
    lset listing end "[lindex $listing end][format {%12s } $newX]"
    incr pos
    set newX
  }]
  return [list $res $listing]
} -test {{ns t} {
  # TODO: Add test for label that doesn't exist
  # TODO: Add test for $var not being substituted
  set cases {
    { pass1Output {4 2 4 hello 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 {$-2} 2}}
    { pass1Output {4 2 4 hello+9 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 {$-2+9} 2}}
    { pass1Output {4 2 4 $ 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 {$} 2}}
    { pass1Output {4 2 4 $+5 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 {$+5} 2}}
    { pass1Output {4 2 4 OUT 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 -1 2}}
    { pass1Output {4 2 4 0-(hello) 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 {0-($-2)} 2}}
    { pass1Output {4 2 4 OUT-2 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 -1-2 2}}
  }
  foreach case $cases {
    dict with case {
      # TODO: Test listing
      lassign [${ns}::pass2 $pass1Output $constants $labels] gotResult
      if {$gotResult != $result} {
        xproc::fail $t "got result: $gotResult, want: $result"
      }
    }
  }
}}


# Resolve relative addresses to absolute addresses
xproc::proc pass3 {pass2Output} {
  lappend listing "\nPass 3\n======\n"
  set pos 0
  set res [lmap x $pass2Output {
    if {[expr $pos % 5] == 0} {
      lappend listing [format "%4i  " $pos]
    }
    set newX [expr [list [string map [list $ $pos] $x]]]
    incr pos
    lset listing end "[lindex $listing end][format {%7s } $newX]"
    set newX
  }]
  return [list $res $listing]
}

proc labelCmp {a b} {
  return [expr {[string length $a] < [string length $b]}]
}

proc sortLabelsByLength {labels} {
  return [lsort -stride 2 -command labelCmp $labels]
}


# Return: {macros lineNum listing errors}
proc compileMacro {src lineNum start macros} {
  set errors {}
  set mArgs {}
  set startLineNum $lineNum           ; # This is for error reporting
  set line [lindex $src $lineNum]
  while 1 {
    lassign [getWord $line $start] word wordEnd
    if {$word eq ""} {break}
    lappend mArgs $word
    set start [expr {$wordEnd+1}]
  }
  incr lineNum
  if {[llength $mArgs] < 1} {
    lappend errors [makeError $startLineNum $line "Macro name not supplied"]
    return [list $macros $lineNum {} $errors]
  }
  set name [lindex $mArgs 0]
  if {[dict exists $macros $name]} {
    lappend errors [makeError $startLineNum $line \
                              "Macro already exists: $name"]
    return [list $macros $lineNum {} $errors]
  }
  set parameters [lrange $mArgs 1 end]
  while 1 {
    set line [lindex $src $lineNum]
    if {[string trimleft [string match ".endm*" $line]]} {break}
    incr lineNum
    lappend body $line
  }
  lassign [pass1 "Macro: $name" $body $macros] \
          pass1Output constants labels pass1Listing pass1Errors
  if {[llength $pass1Errors] > 0} {
    set pass1Errors [renumberErrors $pass1Errors $startLineNum]
    set errors [list {*}$errors {*}$pass1Errors]
    return [list $macros $lineNum {} $errors]
  }
  lassign [pass2 $pass1Output $constants $labels] body pass2Listing
  set macros [
    dict set macros $name [dict create params $parameters body $body]
  ]
  return [list $macros $lineNum [list {*}$pass1Listing {*}$pass2Listing] {}]
}


# This is used because otherwise line numbers for macros would be in
# relation to the start of the macro definition not the start of the file
proc renumberErrors {errors startLineNum} {
  return [lmap err $errors {
    set oldLineNum [dict get $err lineNum]
    dict set err lineNum [expr {$startLineNum+1+$oldLineNum}]
  }]
}


xproc::proc runMacro {name line start macros} {
  set mArgs {}
  while 1 {
    lassign [getWord $line $start] word wordEnd
    if {$word eq "" || [isComment $word]} {break}
    lappend mArgs $word
    set start [expr {$wordEnd+1}]
  }

  if {![dict exists $macros $name]} {
    return -code error "Unknown macro: $name"
  }
  set macro [dict get $macros $name]
  set params [dict get $macro params]
  set body [dict get $macro body]

  if {[llength $params] != [llength $mArgs]} {
    return -code error "Wrong number of arguments"
  }
  set labels [dict create]
  for {set i 0} {$i < [llength $mArgs]} {incr i} {
    dict set labels [lindex $params $i] [lindex $mArgs $i]
  }
  set labels [sortLabelsByLength $labels]
  return [list $mArgs [string map $labels $body]]
}


# Test normal execution
xproc::test -id 1 runMacro {{ns t} {
  set macros {
    add {params {a b} body {a z ?+1 z b ?+1 z z ?+1}}
    inc {params {addr} body {minusOne addr ?+1}}
    nop {params {} body {z z ?+1}}
  }
  set cases [list \
    [dict create name inc line {inc boris} start 3 macros $macros \
                 result {boris {minusOne boris ?+1}}] \
    [dict create name add line {add num sum} start 3 macros $macros \
                 result {{num sum} {num z ?+1 z sum ?+1 z z ?+1}}] \
    [dict create name nop line {nop} start 3 macros $macros \
                 result {{} {z z ?+1}}]
  ]
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::runMacro $name $line $start $macros}
  }}
}}


# Test errors
xproc::test -id 2 runMacro {{ns t} {
  set macros {
    inc {params {addr} body {minusOne addr ?+1}}
    add {params {a b} body {a z ?+1 z b ?+1 z z ?+1}}
  }
  set cases [list \
    [dict create name inc line {inc boris janet} start 3 macros $macros \
                 result {error {Wrong number of arguments}}] \
    [dict create name inc line {inc } start 3 macros $macros \
                 result {error {Wrong number of arguments}}] \
    [dict create name mov line {mov boris janet} start 3 macros $macros \
                 result {error {Unknown macro: mov}}] \
  ]
  xproc::testCases $t $cases {{ns case} {
    try {
      dict with case {${ns}::runMacro $name $line $start $macros}
      list ok {}
    } on error {err} {
      list error $err
    }
  }}
}}


# Get remainder of 'sble' instruction operands
proc getSbleInstruction {line start} {
  lassign [getWord $line $start] aOp aEnd
  lassign [getWord $line [expr {$aEnd+1}]] bOp bEnd
  lassign [getWord $line [expr {$bEnd+1}]] cOp cEnd

  if {$aOp eq "" || $bOp eq "" || [isComment $aOp] || [isComment $bOp]} {
    return -code error "Wrong number of arguments"
  }
  if {$cOp eq "" || [isComment $cOp]} {
    set cEnd $bEnd
    set cOp {$+1}
  }
  return [list [list $aOp $bOp $cOp] $cEnd]
}


# Returns: {str nums end}
xproc::proc getString {line linePos} {
  if {[string index $line $linePos] ne "\""} {
    return -code error "String must begin with \""
  }
  set start [expr {$linePos+1}]
  set end [string first "\"" $line $start]
  if {$end == -1} {
    return -code error "String must end with \""
  }
  set str1 [string range $line $start [expr {$end-1}]]
  set str2 [subst -nocommands -novariables $str1]
  set chars [split $str2 ""]
  set nums [lmap ch $chars {scan $ch "%c"}]
  return [list $str1 $nums $end]
} -test {{ns t} {
  set cases {
    {line {.ascii "hello"} linePos 7 result {hello {104 101 108 108 111} 13}}
    {line {.ascii "hello e"} linePos 7
     result {{hello e} {104 101 108 108 111 32 101} 15}}
    {line {.ascii "hello\n"} linePos 7
     result {{hello\n} {104 101 108 108 111 10} 15}}
    {line {.ascii ""} linePos 7 result {{} {} 8}}
  }
  xproc::testCases $t $cases {{ns case} {
    set case [dict create {*}$case]
    dict with case {${ns}::getString $line $linePos}
  }}
}}


proc skipWhitespace {line pos} {
  if {[regexp -indices -start $pos {[^\s]} $line location]} {
    return [lindex $location 0]
  }
  return [string length $line]
}

proc nextWhitespace {line pos} {
  if {[regexp -indices -start $pos {\s} $line location]} {
    return [lindex $location 0]
  }
  return [string length $line]
}

# Get the next word
# Returns {word end}
proc getWord {line pos} {
  set start [skipWhitespace $line $pos]
  set end [expr {$start-1}]
  for {set i $start} {$i < [string length $line]} {incr i} {
    set ch [string index $line $i]
    if {![string is space $ch]} {
      incr end
    } else {
      break
    }
  }
  set word [string range $line $start $end]
  return [list $word $end]
}


proc isDefineLabel {word} {
  return [string match {?*:} $word]
}


proc isComment {word} {
  return [string match {;*} $word]
}


proc isCommand {word} {
  return [string match {.?*} $word]
}


proc isSbleInstruction {word} {
  return [string match {sble} $word]
}
