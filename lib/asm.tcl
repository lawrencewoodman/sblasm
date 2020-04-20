#! /usr/bin/env tclsh
#
# SUBLEQ assembler routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


xproc::proc assemble {src} {
  lassign [pass1 "Main" $src] pass1Output constants labels pass1Listing
  lassign [pass2 $pass1Output $constants $labels] pass2Output pass2Listing
  lassign [pass3 $pass2Output] pass3Output pass3Listing
  set listing [list {*}$pass1Listing {*}$pass2Listing {*}$pass3Listing]
  return [list $pass3Output $listing]
}


proc pass1 {srcName src {macros {}}} {
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
        # TODO: Error check properly and place in separate procs
        switch $word {
          .ascii {
            set start [skipWhitespace $line [expr {$wordEnd+1}]]
            lassign [getString $line $start] charNums wordEnd
            if {[llength $charNums] > 0} {
              lappend codeListing [list $pos ascii $charNums]
              lappend result {*}$charNums
              incr pos [llength $charNums]
            }
          }
          .equ {
            lassign [getWord $line [expr {$wordEnd+1}]] name wordEnd
            lassign [getWord $line [expr {$wordEnd+1}]] val wordEnd
            dict set constants $name $val
          }
          .macro {
            set nextPos [expr {$wordEnd+1}]
            lassign [compileMacro $src $lineNum $nextPos $macros] \
                    macros lineNum macroListing
            lappend listing {*}$macroListing
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
        dict set labels [string trimright $word :] $pos
        lappend codeListing [list $pos label $word]
      } elseif {[isSubleqInstruction $word]} {
        lassign [getSubleqInstruction $line [expr {$wordEnd+1}]] \
                instruction wordEnd
        if {[llength $instruction] == 3} {
          lappend codeListing [list $pos sble $instruction]
          lappend result {*}$instruction
          incr pos 3
        }
      } else {
        set name $word
        lassign [runMacro $name $line [expr {$wordEnd+1}] $macros] mArgs body
        lappend result {*}$body
        lappend codeListing [list $pos macro $name $mArgs]
        incr pos [llength $body]
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

  return [list $result $constants $labels $listing]
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
      if {[dict exists $labelOffsets $x]} {
        set newX [dict get $labelOffsets $x]
      } elseif {[dict exists $constants $x]} {
        set newX [dict get $constants $x]
      } else {
        set labelOffsets [sortLabelsByLength $labelOffsets]
        set newX [string map $labelOffsets $x]
      }
    }
    lset listing end "[lindex $listing end][format {%12s } $newX]"
    incr pos
    set newX
  }]
  return [list $res $listing]
} -test {{ns t} {
  # TODO: Add test for label that doesn't exist
  # TODO: Add test for $var not being substituted
  # TODO: Add support for calculations on constants
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
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::pass2 $pass1Output $constants $labels}
  }}
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

proc compileMacro {src lineNum start macros} {
  set mArgs {}
  set line [lindex $src $lineNum]
  while 1 {
    lassign [getWord $line $start] word wordEnd
    if {$word eq ""} {break}
    lappend mArgs $word
    set start [expr {$wordEnd+1}]
  }
  incr lineNum
  if {[llength $mArgs] < 1} {
    puts stderr "Invalid line: $line"
    return [list $macros $lineNum {}]
  }
  set name [lindex $mArgs 0]
  set parameters [lrange $mArgs 1 end]
  while 1 {
    set line [lindex $src $lineNum]
    if {[string trimleft [string match ".endm*" $line]]} {break}
    incr lineNum
    lappend body $line
  }
  lassign [pass1 "Macro: $name" $body $macros] \
          pass1Output constants labels pass1Listing
  lassign [pass2 $pass1Output $constants $labels] body pass2Listing
  set macros [
    dict set macros $name [dict create params $parameters body $body]
  ]
  return [list $macros $lineNum [list {*}$pass1Listing {*}$pass2Listing]]
}


proc runMacro {name line start macros} {
  set mArgs {}
  while 1 {
    lassign [getWord $line $start] word wordEnd
    if {$word eq "" || [isComment $word]} {break}
    lappend mArgs $word
    set start [expr {$wordEnd+1}]
  }

  if {![dict exists $macros $name]} {
    puts stderr "Invalid line: $line"
    return {}
  }
  set macro [dict get $macros $name]
  set params [dict get $macro params]
  set body [dict get $macro body]

  if {[llength $params] != [llength $mArgs]} {
    puts stderr "Invalid line: $line"
    return {}
  }
  set labels [dict create]
  for {set i 0} {$i < [llength $mArgs]} {incr i} {
    dict set labels [lindex $params $i] [lindex $mArgs $i]
  }
  set labels [sortLabelsByLength $labels]
  return [list $mArgs [string map $labels $body]]
}


# Get remainder of Subleq instruction operands
proc getSubleqInstruction {line start} {
  lassign [getWord $line $start] aOp aEnd
  lassign [getWord $line [expr {$aEnd+1}]] bOp bEnd
  lassign [getWord $line [expr {$bEnd+1}]] cOp cEnd

  if {$aOp eq "" || $bOp eq "" || [isComment $aOp] || [isComment $bOp]} {
    puts stderr "Invalid line: $line"
    return [list {} $cEnd]
  }
  if {$cOp eq "" || [isComment $cOp]} {
    set cEnd $bEnd
    set cOp {$+1}
  }
  return [list [list $aOp $bOp $cOp] $cEnd]
}


xproc::proc getString {line linePos} {
  if {[string index $line $linePos] ne "\""} {
    puts stderr "Invalid line: $line"
    return [list "" $linePos]
  }
  set start [expr {$linePos+1}]
  set end [string first "\"" $line $start]
  if {$end == -1} {
    puts stderr "Invalid line: $line"
    return [list "" $linePos]
  }
  set str [string range $line $start [expr {$end-1}]]
  set str [subst -nocommands -novariables $str]
  set chars [split $str ""]
  set nums [lmap ch $chars {scan $ch "%c"}]
  return [list $nums $end]
} -test {{ns t} {
  set cases {
    {line {.ascii "hello"} linePos 7 result {{104 101 108 108 111} 13}}
    {line {.ascii "hello\n"} linePos 7 result {{104 101 108 108 111 10} 15}}
    {line {.ascii ""} linePos 7 result {{} 8}}
  }
  xproc::testCases $t $cases {{ns case} {
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
  return [string match {#*} $word]
}


proc isCommand {word} {
  return [string match {.?*} $word]
}


proc isSubleqInstruction {word} {
  return [string match {sble} $word]
}
