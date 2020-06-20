# SUBLEQ assembler routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# Return {output listing errors}
xproc::proc assemble {filename src} {
  lassign [lex $filename $src] tokens symbols lexErrors
  if {[llength $lexErrors] > 0} {
    return [list {} {} $lexErrors]
  }

  lassign [parser::parse -lpool $filename $tokens $symbols] \
          code macros symbols listing errors
  if {[llength $errors] > 0} {
    return [list {} {} $errors]
  }
  set pass2Output [pass2 $code 0 $symbols]
  lassign [pass3 $pass2Output] pass3Output errors
  if {[llength $errors] > 0} {
    return [list {} $listing $errors]
  }

  set prettyListing {}

  # TODO: Rename all this
  # TODO: Add symbol table listing
  dict for {_filename fileListing} $listing {
    append prettyListing \
           "$_filename\n[string repeat "=" [string length $_filename]]\n\n"
    dict for {type typeListing} $fileListing {
      if {$type eq "main"} {
        append prettyListing "Main\n----\n\n"
        set typeListing [addPass3CodeToFileListing $typeListing $pass3Output]
        append prettyListing "[prettyFormatFileListing $typeListing]\n"
      } elseif {$type eq "macros"} {
        dict for {macroName macroListing} $typeListing {
          append prettyListing "\nMacro: $macroName\n"
          append prettyListing \
                 "[string repeat "-" [expr {[string length $macroName]+7}]]\n"
          append prettyListing "\n"
          append prettyListing "[prettyFormatFileListing $macroListing]\n"
        }
      } else {
        return -code error "invalid listing type: $type"
      }
    }
  }
  return [list $pass3Output $prettyListing {}]
}


# TODO: Rename
proc addPass3CodeToFileListing {fileListing code} {
  set pos 0
  set entryNum 1

  set i 0
  set positions [lsort -integer [dict keys $fileListing]]
  foreach pos $positions {
    set entry [dict get $fileListing $pos]
    if {$i+1 < [llength $positions]} {
      set nextPos [lindex $positions [expr {$i+1}]]
      dict set entry code [lrange $code $pos [expr {$nextPos-1}]]
    } else {
      if {[dict exists $entry code]} {
        set _code [dict get $entry code]
        set codeLength [llength $_code]
        dict set entry code [lrange $code $pos [expr {$pos+$codeLength}]]
      }
    }
    dict set fileListing $pos $entry
    incr i
  }
  return $fileListing
}


# Compares entries in listing where the key value pair have
# been put into a list to ease sorting
proc compareListingEntries {a b} {
  lassign $a aPos aEntry
  lassign $b bPos bEntry
  if {$aPos >= 0 & $bPos >= 0} {
    if {$aPos < $bPos} {
      return -1
    } elseif {$bPos < $aPos} {
      return 1
    }
  }
  lassign [dict get $aEntry tokens] aToken
  lassign [dict get $bEntry tokens] bToken
  set aLineNum [lindex $aToken 2]
  set bLineNum [lindex $bToken 2]
  return [expr {$aLineNum - $bLineNum}]
}


proc sortFileListing {fileListing} {
  set entryLists {}
  set res {}
  dict for {k v} $fileListing {
    lappend entryLists [list $k $v]
  }

  set entryLists [lsort -command compareListingEntries $entryLists]
  foreach entryList $entryLists {
    lassign $entryList k v
    dict set res $k $v
  }
  return $res
}


proc prettyFormatFileListing {fileListing} {
  set formattedListing "Line  Pos\n"
  set label ""
  set lastEntry {}
  dict for {pos entry} [sortFileListing $fileListing] {
    set label ""
    set nonLabelValues {}
    set lastEntry $entry
    if {[dict exists $entry tokens]} {
      set tokens [dict get $entry tokens]
      foreach token $tokens {
        lassign $token type val lineNum
        switch $type {
          label {
            set label $val
          }
          directive {
            lappend nonLabelValues $val
          }
          string {
            lappend nonLabelValues "\"$val\""
          }
          id {
            lappend nonLabelValues $val
          }
          literal {
            lappend nonLabelValues $val
          }
          num {
            lappend nonLabelValues $val
          }
          expr {
            lappend nonLabelValues $val
          }
          EOL {}
          comment {
          }
          default {
            return -code error "Unknown type: $type"
          }
        }
      }
      if {$label ne ""} {
        append label ":"
      }
      if {$lineNum < 0} {
        set lineNum ""
      }
      if {$pos < 0} {
        set pos ""
      }
      if {[string length $label] >= 9} {
        append formattedListing [format "%4s %4s %s\n" \
               $lineNum $pos $label]
        set label ""
      }
      if {[llength $nonLabelValues] > 0} {
        lassign $nonLabelValues firstVal
        set restVals [lrange $nonLabelValues 1 end]
        append formattedListing \
               [format "%4s %4s %-10s %-5s %s\n" \
                        $lineNum $pos $label $firstVal [join $restVals]]
      }
    }
    if {[dict exists $entry code]} {
      set code [dict get $entry code]
      set i 0
      while {$i < [llength $code]} {
        append formattedListing [format {%4s %4s %-10s} "" ">" ""]
        set lineLength 16
        while {$i < [llength $code]} {
          set codePoint [lindex $code $i]
          if {$lineLength + [string length $codePoint] + 1 < 79} {
            append formattedListing " $codePoint"
            incr lineLength [expr {[string length $codePoint]+1}]
          } else {
            append formattedListing "\n"
            break
          }
          incr i
        }
      }
      append formattedListing "\n\n"
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

xproc::proc resolveLabels {src labels} {
  set srcPos 0
  set res [list]

  foreach expr $src {
    set newExpr ""
    set exprTokens [lexExpr $expr]
    foreach token $exprTokens {
      lassign $token type val
      switch $type {
        num -
        operator {append newExpr $val}
        label -
        literal {
          if {[dict exists $labels $val]} {
            append newExpr [dict get $labels $val]
          } else {
            append newExpr $val
          }
        }
        default {
          return -code error "unknown type: $type"
        }
      }
    }
    lappend res $newExpr
  }
  return $res
} -test {{ns t} {
  set cases {
    { src "this+4/is-3+a*i" labels {this 100 is 2000 a 30000 i 400000}
      result {100+4/2000-3+30000*400000}}
    { src "num1+num2+3+4" labels {num1 200 num2 3000}
      result {200+3000+3+4}}
    { src "this+$/is-3+a*i" labels {$ 70 this 100 is 2000 a 30000 i 400000}
      result {100+70/2000-3+30000*400000}}
    { src "20+a+#7+3-#-45" labels {a 9 #7 100 #-45 20}
      result {20+9+100+3-20}}
    { src "-4 5 62 #7 a" labels {a 9 #7 100}
      result {-4 5 62 100 9}}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::resolveLabels $src $labels}
  }}
}}


# resolve labels pass
proc pass2 {pass1Output startPos symbols} {
  set pos $startPos
  set labels {}
  set constants {}
  # TODO: This is just for testing
  dict for {name details} $symbols {
    switch [dict get $details type] {
      label {dict set labels $name [dict get $details pos]}
      constant {dict set constants $name [dict get $details val]}
      literal {}
      default {
        puts "unknown type: [dict get $details type]"
      }
    }
  }

  set res [lmap x $pass1Output {
    set newX $x
    if {![string is integer $x]} {
      set labelOffsets [calcLabelOffsets $pos $labels]
      set names [joinLabelsConstants $constants $labelOffsets]
      set newX [resolveLabels $x $names]
    }
    incr pos
    set newX
  }]
  return $res
}


# Resolve relative addresses to absolute addresses
# Return: {output errors}
xproc::proc pass3 {pass2Output} {
  set errors {}
  set pos 0
  set res [lmap x $pass2Output {
    set newX $x            ; # Needed in case of error
    try {
      set newX [expr [list [resolveLabels $x [list $ $pos]]]]
    } on error {err opts} {
      if {"BAREWORD" in [dict get $opts -errorcode]} {
        lappend errors [dict create pos $pos msg "Unknown label: $x"]
      } else {
        lappend errors [dict create pos $pos msg $err]
      }
    }
    incr pos
    set newX
  }]
  return [list $res $errors]
}


# TODO: Add tests for runMacro method similar to below in lib/parser

# Test normal execution
#xproc::test -id 1 runMacro {{ns t} {
#  set macros {
#    add {params {a b} body {a z $+1 z b $+1 z z $+1}}
#    inc {params {addr} body {minusOne addr $+1}}
#    nop {params {} body {z z $+1}}
#  }
#  set cases [list \
#    [dict create tokens {{id inc 3} {id boris 3}} tokenNum 0 macros $macros \
#                 result {inc boris {minusOne boris $+1} {} 2}] \
#    [dict create tokens {{id nop 3} {id inc 3} {id boris 3}} \
#                 tokenNum 1 macros $macros \
#                 result {inc boris {minusOne boris $+1} {} 3}] \
#    [dict create tokens {{id nop 3} {id inc 4} {id boris 4}} \
#                 tokenNum 0 macros $macros \
#                 result {nop {} {z z $+1} {} 1}] \
#    [dict create tokens {{id add 3} {id num 3} {id sum 3}} \
#                 tokenNum 0 macros $macros \
#                 result {add {num sum} {num z $+1 z sum $+1 z z $+1} {} 3}] \
#    [dict create tokens {{id nop 1}} tokenNum 0 macros $macros \
#                 result {nop {} {z z $+1} {} 1}]
#  ]
#  xproc::testCases $t $cases {{ns case} {
#    set filename "hello.asq"
#    dict with case {${ns}::runMacro $filename $tokens $tokenNum $macros}
#  }}
#}}


# Test errors
#xproc::test -id 2 runMacro {{ns t} {
#  set macros {
#    inc {params {addr} body {minusOne addr ?+1}}
#    add {params {a b} body {a z ?+1 z b ?+1 z z ?+1}}
#  }
#  set cases [list \
#    [dict create filename "incboris.asq" \
#                 tokens {{id inc 3} {id boris 3} {id janet 3}} \
#                 tokenNum 0 macros $macros \
#                 result [list {} {} {} \
#                   [list [dict create filename "incboris.asq" \
#                                lineNum 3 \
#                                line "inc boris janet" \
#                                msg {Wrong number of arguments}]] \
#                   3]] \
#    [dict create filename "inc.asq" \
#                 tokens {{id inc 3}} tokenNum 0 macros $macros \
#                 result [list {} {} {} \
#                   [list [dict create filename "inc.asq" \
#                                lineNum 3 \
#                                line "inc" \
#                                msg {Wrong number of arguments}]] \
#                   1]] \
#    [dict create filename "movboris.asq" \
#                 tokens {{id mov 3} {id boris 3} {id janet 3}} \
#                 tokenNum 0 macros $macros \
#                 result [list {} {} {} \
#                   [list [dict create filename "movboris.asq" \
#                                lineNum 3 \
#                                line "mov boris janet" \
#                                msg {Unknown macro: mov}]] \
#                   3]] \
#  ]
#  xproc::testCases $t $cases {{ns case} {
#    dict with case {${ns}::runMacro $filename $tokens $tokenNum $macros}
#  }}
#}}
