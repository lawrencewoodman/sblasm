# SUBLEQ assembler routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# Return {output listing errors}
xproc::proc assemble {filename src} {
  # TODO: Add something to listing?
  lassign [lex $filename $src] tokens literals lexErrors
  if {[llength $lexErrors] > 0} {
    return [list {} {} $lexErrors]
  }

  lassign [pass1 $filename "Main" $tokens 0 $literals] \
      pass1Output constants labels macros pass1Listing errors
  if {[llength $errors] > 0} {
    return [list {} {} $errors]
  }
  lassign [pass2 $pass1Output 0 $constants $labels] pass2Output pass2Listing
  lassign [pass3 $pass2Output] pass3Output pass3Listing errors
  if {[llength $errors] > 0} {
    set listing [list {*}$pass1Listing {*}$pass2Listing]
    return [list {} $listing $errors]
  }
  set listing [list {*}$pass1Listing {*}$pass2Listing {*}$pass3Listing]
  return [list $pass3Output $listing {}]
}


# TODO: Rename this - should lexer be pass1?
# Args:
#   startPos  - the start position in memory of the code
# Return {output constants labels macros listing errors}
proc pass1 {
  filename
  srcName
  tokens
  startPos
  {literals {}}
  {constants {}}
  {labels {}}
  {macros {}}
} {
  set errors [list]
  set codeListing {}
  set pos $startPos
  set result [list]
  set lineNum 1
  set tokenNum 0
  while {$tokenNum < [llength $tokens]} {
    set token [lindex $tokens $tokenNum]
    lassign $token type value lineNum
    switch $type {
      comment {incr tokenNum}
      directive {
        switch $value {
          .ascii {
            lassign [getAsciiString .ascii $filename $tokens $tokenNum] \
                    str charNums charNumErrors
            if {[llength $charNumErrors] > 0} {
              set errors [list {*}$errors {*}$charNumErrors]
              set tokenNum [nextLineTokenNum $tokens $tokenNum]
              continue
            }
            lappend codeListing [list $pos ascii \"$str\"]
            lappend result {*}$charNums
            incr pos [llength $charNums]
            incr tokenNum 2
          }
          .asciiz {
            lassign [getAsciiString .asciiz $filename $tokens $tokenNum] \
                    str charNums charNumErrors
            if {[llength $charNumErrors] > 0} {
              set errors [list {*}$errors {*}$charNumErrors]
              set tokenNum [nextLineTokenNum $tokens $tokenNum]
              continue
            }
            lappend charNums 0
            lappend codeListing [list $pos asciiz \"$str\"]
            lappend result {*}$charNums
            incr pos [llength $charNums]
            incr tokenNum 2
          }
          .equ {
            # Get ID
            set err ""
            set startTokenNum $tokenNum
            incr tokenNum
            set nextToken [lindex $tokens $tokenNum]
            lassign $nextToken nextType nextValue nextLineNum
            set id $nextValue
            if {$lineNum != $nextLineNum} {
              set err "Missing identifier for .equ"
              lappend errors [
                makeError $filename $tokens [expr {$tokenNum-1}] $err
              ]
            } elseif {$nextType ne "id"} {
              set err "Invalid identifier for .equ"
              lappend errors [makeError $filename $tokens $tokenNum $err]
            } elseif {[dict exists $labels $id]} {
              set err "Name clash: $id"
              lappend errors [makeError $filename $tokens $tokenNum $err]
            }
            if {$err ne ""} {
              set tokenNum [nextLineTokenNum $tokens $startTokenNum]
              continue
            }

            # Get value
            set lineNum $nextLineNum
            incr tokenNum
            set nextToken [lindex $tokens $tokenNum]
            lassign $nextToken nextType nextValue nextLineNum
            if {$lineNum != $nextLineNum} {
              set err "Missing value for .equ"
              lappend errors [
                makeError $filename $tokens [expr {$tokenNum-1}] $err
              ]
            } elseif {$nextType ne "num"} {
              set err "Invalid number for .equ"
              lappend errors [makeError $filename $tokens $tokenNum $err]
            }
            if {$err ne ""} {
              set tokenNum [nextLineTokenNum $tokens $startTokenNum]
              continue
            }
            dict set constants $id $nextValue
            incr tokenNum
          }
          .include {
            set err ""
            set startTokenNum $tokenNum
            incr tokenNum
            set nextToken [lindex $tokens $tokenNum]
            lassign $nextToken nextType nextValue nextLineNum
            set incFilename $nextValue
            if {$lineNum != $nextLineNum} {
              set err "Missing filename for .include"
              lappend errors [
                makeError $filename $tokens [expr {$tokenNum-1}] $err
              ]
            } elseif {$nextType ne "string"} {
              set err "Invalid filename for .include"
              lappend errors [makeError $filename $tokens $tokenNum $err]
            }
            if {$err ne ""} {
              set tokenNum [nextLineTokenNum $tokens $startTokenNum]
              continue
            }

            try {
              lassign [compileInclude $incFilename $pos $constants \
                                      $labels $macros] \
                      incOutput incLiterals constants labels macros \
                      incListing incErrors
              if {[llength $incErrors] > 0} {
                set errors [list {*}$errors {*}$incErrors]
              } else {
                set literals [list {*}$literals {*}$incLiterals]
                lappend listing {*}$incListing
                lappend result {*}$incOutput
                lappend codeListing [list $pos include $incFilename]
                incr pos [llength $incOutput]
              }
            } on error {err} {
              lappend errors [makeError $filename $tokens $tokenNum $err]
            }
            incr tokenNum
          }
          .lpool {
            # Literal pool
            # TODO: Ensure that there is only one .lpool per file
            # TODO: Try to have one .lpool for the whole project
            # TODO: Test for nested include files
            set lpool [lsort -unique $literals]
            foreach litLabel $lpool {
              set lit [string trimleft $litLabel "#"]
              dict set labels $litLabel $pos
              lappend codeListing [list $pos label $litLabel]
              lappend codeListing [list $pos word $lit]
              lappend result $lit
              incr pos
            }
            incr tokenNum
          }
          .macro {
            lassign [compileMacro $filename $tokens $tokenNum $macros] \
                    macros macroListing macroErrors tokenNum
            if {[llength $macroErrors] > 0} {
              set errors [list {*}$errors {*}$macroErrors]
            } else {
              lappend listing {*}$macroListing
            }
          }
          .word {
            set err ""
            set wordValues [list]
            incr tokenNum
            for {} {$tokenNum < [llength $tokens]} {incr tokenNum} {
              set nextToken [lindex $tokens $tokenNum]
              lassign $nextToken nextType nextValue nextLineNum
              if {$lineNum != $nextLineNum} {
                break
              } elseif {$nextType eq "comment"} {
                break
              } elseif {$nextType ni {id num expr}} {
                set err "Invalid value for .word"
                lappend errors [makeError $filename $tokens $tokenNum $err]
                break
              } else {
                lappend wordValues $nextValue
              }
            }

            if {[llength $wordValues] == 0} {
              set err "Missing values for .word"
              lappend errors [makeError $filename $tokens $tokenNum $err]
            }
            if {$err ne ""} {
              continue
            }

            # TODO: Test listing with multiple word values
            lappend codeListing [list $pos word $wordValues]
            lappend result {*}$wordValues
            incr pos [llength $wordValues]
          }
          default {
            set err "Unknown assembler directive: $value"
            lappend errors [makeError $filename $tokens $tokenNum $err]
            set tokenNum [nextLineTokenNum $tokens $tokenNum]
          }
        }
      }
      label {
        if {[dict exists $constants $value]} {
          set err "Name clash: $value"
          lappend errors [makeError $filename $tokens $tokenNum $err]
        } elseif {[dict exists $labels $value]} {
          set err "Label exists: $value"
          lappend errors [makeError $filename $tokens $tokenNum $err]
        } else {
          dict set labels $value $pos
          lappend codeListing [list $pos label $value]
        }
        incr tokenNum
      }
      id {
        if {$value eq "sble"} {
          lassign [getSbleInstruction $filename $tokens $tokenNum] \
                  instruction sbleErrors tokenNum
          if {[llength $sbleErrors] > 0} {
            set errors [list {*}$errors {*}$sbleErrors]
          } else {
            lappend result {*}$instruction
            lappend codeListing [list $pos sble $instruction]
            incr pos 3
          }
        } else {
          lassign [runMacro $filename $tokens $tokenNum $macros] \
                  macroName macroArgs macroBody macroErrors tokenNum
          if {[llength $macroErrors] > 0} {
            set errors [list {*}$errors {*}$macroErrors]
          } else {
            lappend result {*}$macroBody
            # TODO: perhaps code listing should consist of pos plus lineTokens
            lappend codeListing [list $pos macro $macroName $macroArgs]
            incr pos [llength $macroBody]
          }
        }
      }
      default {
        lappend errors [makeError $filename $tokens $tokenNum "Syntax error"]
        set tokenNum [nextLineTokenNum $tokens $tokenNum]
      }
    }
  }

  lappend listing "\nPass 1 - $srcName"
  lappend listing "[string repeat "=" [expr {[string length $srcName]+9}]]\n"
  if {[llength $constants] > 0} {
    lappend listing "Constants\n---------\n$constants\n"
  }
  lappend listing "Listing\n-------\n"
  lappend listing [format {%4s} "Pos"]

  lappend listing {*}[prettyFormatCodeListing $codeListing]
  lappend listing "\n"

  return [list $result $constants $labels $macros $listing $errors]
}


# Get the tokens for the line that the token at tokenNum is on
proc getLineTokens {tokens tokenNum} {
  lassign [lindex $tokens $tokenNum] startType startValue startLineNum
  for {} {$tokenNum >= 0} {incr tokenNum -1} {
    lassign [lindex $tokens $tokenNum] type value lineNum
    if {$lineNum != $startLineNum} {
      break
    }
  }

  incr tokenNum
  set line [list]
  for {} {$tokenNum < [llength $tokens]} {incr tokenNum} {
    set token [lindex $tokens $tokenNum]
    lassign $token type value lineNum
    if {$lineNum != $startLineNum} {
      break
    }
    lappend line $token
  }
  return $line
}


proc lineTokensToLine {tokens} {
  set line [list]
  foreach token $tokens {
    lassign $token type value lineNum
    # TODO: test for comments and strings
    switch $type {
      comment {lappend line "; $value"}
      label {lappend line "$value:"}
      default {lappend line $value}
    }
  }
  return [join $line " "]
}


proc makeError {filename tokens tokenNum error} {
  set lineTokens [getLineTokens $tokens $tokenNum]
  lassign [lindex $lineTokens 0] type value lineNum
  set line [lineTokensToLine $lineTokens]
  return [dict create filename $filename \
                      lineNum $lineNum line $line msg $error]
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

xproc::proc resolveLabels {src labels} {
  # TODO: Document Valid labels - note labels mustn't include a $
  # TODO: this should only be for getting the current address
  set pos 0
  set res {}

  while {$pos != -1 && $pos < [string length $src]} {
    set restSrc [string range $src $pos end]
    switch -regexp -matchvar matches -indexvar indices -- $restSrc {
      {^\s+} {
        # Whitespace
        lassign [lindex $indices 0] start end
        append res [lindex $matches 0]
        incr pos [expr {$end+1}]
     }
      {^[+\-/*()]} {
        # Operator
        append res [lindex $matches 0]
        incr pos
      }
      {^#[-]?[0-9]+} {
        # Literal
        lassign [lindex $indices 0] start end
        set lit [string trimright [lindex $matches 0]]
        if {[dict exists $labels $lit]} {
          append res [dict get $labels $lit]
        } else {
          append res [lindex $matches 0]
        }
        incr pos [expr {$end+1}]
      }
      {^[A-Za-z_:][A-Za-z0-9_:]*} {
        # Label
        lassign [lindex $indices 0] start end
        set label [string trimright [lindex $matches 0]]
        if {[dict exists $labels $label]} {
          append res [dict get $labels $label]
        } else {
          append res [lindex $matches 0]
        }
        incr pos [expr {$end+1}]
      }
      {^\$} {
        # Current position
        lassign [lindex $indices 0] start end
        if {[dict exists $labels {$}]} {
          append res [dict get $labels {$}]
        } else {
          append res $
        }
        incr pos
      }
      {^[0-9]+} {
        # Number
        lassign [lindex $indices 0] start end
        append res [lindex $matches 0]
        incr pos [expr {$end+1}]
      }
      {{.*?}} {
        # Braced expression
        lassign [lindex $indices 0] start end
        set bexpr [string trim [lindex $matches 0] "{}"]
        append res {*}[resolveLabels $bexpr $labels]
        incr pos [expr {$end+1}]
      }
      default {
        set pos [string length $src]
      }
    }
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


xproc::proc pass2 {pass1Output startPos constants labels} {
  lappend listing "Pass 2\n======\n"
  lappend listing [format {%4s} "Pos"]
  set pos $startPos
  set res [lmap x $pass1Output {
    if {[expr $pos % 5] == 0} {
      lappend listing [format "%4i  " $pos]
    }
    set newX $x
    if {![string is integer $x]} {
      set labelOffsets [calcLabelOffsets $pos $labels]
      set names [joinLabelsConstants $constants $labelOffsets]
      set newX [resolveLabels $x $names]
    }
    lset listing end "[lindex $listing end][format {%12s } $newX]"
    incr pos
    set newX
  }]
  return [list $res $listing]
} -test {{ns t} {
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
      lassign [${ns}::pass2 $pass1Output 0 $constants $labels] gotResult
      if {$gotResult != $result} {
        xproc::fail $t "got result: $gotResult, want: $result"
      }
    }
  }
}}


# Resolve relative addresses to absolute addresses
# Return: {output listing errors}
xproc::proc pass3 {pass2Output} {
  set errors {}
  lappend listing "\nPass 3\n======\n"
  lappend listing [format {%4s} "Pos"]
  set pos 0
  set res [lmap x $pass2Output {
    if {[expr $pos % 5] == 0} {
      lappend listing [format "%4i  " $pos]
    }
    set newX $x            ; # Needed in case of error
    try {
      set newX [expr [list [resolveLabels $x [list $ $pos]]]]
      lset listing end "[lindex $listing end][format {%7s } $newX]"
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
  return [list $res $listing $errors]
}


proc labelCmp {a b} {
  return [expr {[string length $a] < [string length $b]}]
}


# Return: {macros listing errors tokenNum}
proc compileMacro {filename tokens tokenNum macros} {
  set errors [list]

  # Get macroName
  set err ""
  set token [lindex $tokens $tokenNum]
  set lineNum [lindex $token 2]
  incr tokenNum
  set nextToken [lindex $tokens $tokenNum]
  lassign $nextToken nextType nextValue nextLineNum
  set macroName $nextValue
  if {$lineNum != $nextLineNum} {
    set err "Missing name for .macro"
    lappend errors [makeError $filename $tokens [expr {$tokenNum-1}] $err]
  } elseif {$nextType ne "id"} {
    set err "Invalid name for .macro"
    lappend errors [makeError $filename $tokens $tokenNum $err]
  } elseif {[dict exists $macros $macroName]} {
    set err "Macro already exists: $macroName"
    lappend errors [makeError $filename $tokens $tokenNum $err]
  }

  # Get parameters
  set macroParams [list]
  incr tokenNum
  for {} {$tokenNum < [llength $tokens]} {incr tokenNum} {
    set nextToken [lindex $tokens $tokenNum]
    lassign $nextToken nextType nextValue nextLineNum
    if {$lineNum != $nextLineNum} {
      break
    } elseif {$nextType eq "comment"} {
      break
    } elseif {$nextType ne "id"} {
      set err "Invalid argument: $nextValue"
      lappend errors [makeError $filename $tokens $tokenNum $err]
      continue
    } else {
      lappend macroParams $nextValue
    }
  }

  # Get body
  set lineNum $nextLineNum
  set bodyTokens [list]
  for {} {$tokenNum < [llength $tokens]} {incr tokenNum} {
    set nextToken [lindex $tokens $tokenNum]
    lassign $nextToken nextType nextValue nextLineNum
    if { $nextType eq "directive" && $nextValue eq ".endm"} {
      incr tokenNum
      if {$nextLineNum == $lineNum} {
        set err "Assembler directive must be at beginning of line: .endm"
        lappend errors [makeError $filename $tokens $tokenNum $err]
      }
      break
    } else {
      lappend bodyTokens $nextToken
      set lineNum $nextLineNum
    }
  }

  if {[llength $errors] > 0} {
    return [list $macros {} $errors $tokenNum]
  }

  # ignoreMacros is used in the following because we want to ignore
  # any macros defined within macros
  # TODO: Throw an error if ignoreMacros != macros?
  # TODO: or maybe allow - think more about this.
  lassign [pass1 $filename "Macro: $macroName" $bodyTokens 0 {} {} {} $macros] \
          pass1Output constants labels ignoreMacros \
          pass1Listing pass1Errors
  if {[llength $pass1Errors] > 0} {
    set errors [list {*}$errors {*}$pass1Errors]
    return [list $macros {} $errors $tokenNum]
  }
  lassign [pass2 $pass1Output 0 $constants $labels] body pass2Listing
  set macros [
    dict set macros $macroName [dict create params $macroParams body $body]
  ]
  set listing [list {*}$pass1Listing {*}$pass2Listing]
  return [list $macros $listing {} $tokenNum]
}


# Return {output literals constants labels macros listing errors}
proc compileInclude {filename startPos constants labels macros} {
  set errors {}
  try {
    set src [readFile $filename]
  } on error {err} {
    return -code error "Can't include file: $filename, $err"
  }
  lassign [lex $filename $src] tokens literals lexErrors
  if {[llength $lexErrors] > 0} {
    return [list {} $literals $constants $labels $macros {} $lexErrors]
  }
  lassign [pass1 $filename "File: $filename" $tokens $startPos \
                 $literals $constants $labels $macros] \
          pass1Output constants labels macros pass1Listing \
          pass1Errors
  if {[llength $pass1Errors] > 0} {
    return [list {} $literals $constants $labels $macros $pass1Listing \
                    $pass1Errors]
  }
  lassign [pass2 $pass1Output $startPos $constants $labels] pass2Output pass2Listing
  set listing [list {*}$pass1Listing {*}$pass2Listing]
  return [list $pass2Output $literals $constants $labels $macros \
               $listing $errors]
}


# Return tokenNum for start of next line
# Return: tokenNum
proc nextLineTokenNum {tokens tokenNum} {
  set token [lindex $tokens $tokenNum]
  lassign $token type value lineNum
  while {$tokenNum < [llength $tokens]} {
    set nextToken [lindex $tokens $tokenNum]
    lassign $nextToken nextType nextValue nextLineNum
    if {$lineNum != $nextLineNum} {
      break
    }
    incr tokenNum
  }
  return $tokenNum
}


# Return: {macroName macroArgs macroBody macroErrors tokenNum}
xproc::proc runMacro {filename tokens tokenNum macros} {
  set errors [list]
  set startTokenNum $tokenNum
  set startToken [lindex $tokens $tokenNum]
  lassign $startToken type value lineNum
  set macroName $value

  if {![dict exists $macros $macroName]} {
    set err "Unknown macro: $macroName"
    lappend errors [makeError $filename $tokens $startTokenNum $err]
    return [list {} {} {} $errors [nextLineTokenNum $tokens $startTokenNum]]
  }

  # Get args
  set macroArgs [list]
  incr tokenNum
  for {} {$tokenNum < [llength $tokens]} {incr tokenNum} {
    set nextToken [lindex $tokens $tokenNum]
    lassign $nextToken nextType nextValue nextLineNum
    if {$lineNum != $nextLineNum} {
      break
    } elseif {$nextType eq "comment"} {
      break
    } elseif {$nextType ni {id expr num literal}} {
      set err "Invalid argument: $nextValue"
      lappend errors [makeError $filename $tokens $startTokenNum $err]
    } else {
      lappend macroArgs $nextValue
    }
  }

  if {[llength $errors] > 0} {
    return [list {} {} {} $errors [nextLineTokenNum $tokens $startTokenNum]]
  }

  set macro [dict get $macros $macroName]
  set params [dict get $macro params]
  set body [dict get $macro body]

  if {[llength $params] != [llength $macroArgs]} {
    set err "Wrong number of arguments"
    lappend errors [makeError $filename $tokens $startTokenNum $err]
    return [list {} {} {} $errors [nextLineTokenNum $tokens $startTokenNum]]
  }
  set labels [dict create]
  for {set i 0} {$i < [llength $macroArgs]} {incr i} {
    dict set labels [lindex $params $i] [lindex $macroArgs $i]
  }
  # TODO: this needs to be done for each relevant token
  set body [resolveLabels $body $labels]
  return [list $macroName $macroArgs $body $errors $tokenNum]
}


# Test normal execution
xproc::test -id 1 runMacro {{ns t} {
  set macros {
    add {params {a b} body {a z $+1 z b $+1 z z $+1}}
    inc {params {addr} body {minusOne addr $+1}}
    nop {params {} body {z z $+1}}
  }
  set cases [list \
    [dict create tokens {{id inc 3} {id boris 3}} tokenNum 0 macros $macros \
                 result {inc boris {minusOne boris $+1} {} 2}] \
    [dict create tokens {{id nop 3} {id inc 3} {id boris 3}} \
                 tokenNum 1 macros $macros \
                 result {inc boris {minusOne boris $+1} {} 3}] \
    [dict create tokens {{id nop 3} {id inc 4} {id boris 4}} \
                 tokenNum 0 macros $macros \
                 result {nop {} {z z $+1} {} 1}] \
    [dict create tokens {{id add 3} {id num 3} {id sum 3}} \
                 tokenNum 0 macros $macros \
                 result {add {num sum} {num z $+1 z sum $+1 z z $+1} {} 3}] \
    [dict create tokens {{id nop 1}} tokenNum 0 macros $macros \
                 result {nop {} {z z $+1} {} 1}]
  ]
  xproc::testCases $t $cases {{ns case} {
    set filename "hello.asq"
    dict with case {${ns}::runMacro $filename $tokens $tokenNum $macros}
  }}
}}


# Test errors
xproc::test -id 2 runMacro {{ns t} {
  set macros {
    inc {params {addr} body {minusOne addr ?+1}}
    add {params {a b} body {a z ?+1 z b ?+1 z z ?+1}}
  }
  set cases [list \
    [dict create filename "incboris.asq" \
                 tokens {{id inc 3} {id boris 3} {id janet 3}} \
                 tokenNum 0 macros $macros \
                 result [list {} {} {} \
                   [list [dict create filename "incboris.asq" \
                                lineNum 3 \
                                line "inc boris janet" \
                                msg {Wrong number of arguments}]] \
                   3]] \
    [dict create filename "inc.asq" \
                 tokens {{id inc 3}} tokenNum 0 macros $macros \
                 result [list {} {} {} \
                   [list [dict create filename "inc.asq" \
                                lineNum 3 \
                                line "inc" \
                                msg {Wrong number of arguments}]] \
                   1]] \
    [dict create filename "movboris.asq" \
                 tokens {{id mov 3} {id boris 3} {id janet 3}} \
                 tokenNum 0 macros $macros \
                 result [list {} {} {} \
                   [list [dict create filename "movboris.asq" \
                                lineNum 3 \
                                line "mov boris janet" \
                                msg {Unknown macro: mov}]] \
                   3]] \
  ]
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::runMacro $filename $tokens $tokenNum $macros}
  }}
}}


# Get remainder of 'sble' instruction operands
# Return: {operands errors tokenNum}
proc getSbleInstruction {filename tokens tokenNum} {
  set errors [list]
  set startTokenNum $tokenNum
  set startToken [lindex $tokens $tokenNum]
  lassign $startToken startType startValue startLineNum

  # Get operands
  set operands [list]
  incr tokenNum
  for {set opNum 0} {$tokenNum < [llength $tokens]} \
      {incr tokenNum; incr opNum} {
    set nextToken [lindex $tokens $tokenNum]
    lassign $nextToken nextType nextValue nextLineNum
    if {$startLineNum != $nextLineNum} {
      break
    } elseif {$nextType eq "comment"} {
      break
    } elseif {($opNum >= 1 && $nextType eq "literal") ||
              $nextType ni {id expr num literal}} {
      set err "Invalid argument: $nextValue"
      # TODO: Test literal placement errors
      lappend errors [makeError $filename $tokens $startTokenNum $err]
    } else {
      lappend operands $nextValue
    }
  }

  if {[llength $operands] < 2 || [llength $operands] > 3} {
    set err "Wrong number of arguments"
    lappend errors [makeError $filename $tokens $startTokenNum $err]
  }

  if {[llength $operands] == 2} {
    lappend operands {$+1}
  }
  return [list $operands $errors $tokenNum]
}


# Convert a string to the ascii numbers for it
# NOTE: This performs substitution on the string first
#       to convert \n etc to newlines
# Return: {nums}
xproc::proc stringToNums {str} {
  set str [subst -nocommands -novariables $str]
  return [lmap ch [split $str ""] {scan $ch "%c"}]
} -test {{ns t} {
  set cases {
    {str {hello} result {104 101 108 108 111}}
    {str {hello e} result {104 101 108 108 111 32 101}}
    {str {hello\n} result {104 101 108 108 111 10}}
    {str {} result {}}
  }
  xproc::testCases $t $cases {{ns case} {
    set case [dict create {*}$case]
    dict with case {${ns}::stringToNums $str}
  }}
}}


# Get the string for .ascii/.asciiz
proc getAsciiString {directive filename tokens tokenNum} {
  lassign [lindex $tokens $tokenNum] type value lineNum
  set errors [list]
  incr tokenNum
  set nextToken [lindex $tokens $tokenNum]
  lassign $nextToken nextType nextValue nextLineNum
  if {$lineNum != $nextLineNum} {
    set err "Missing string for $directive"
    lappend errors [makeError $filename $tokens [expr {$tokenNum-1}] $err]
    return [list {} {} $errors]
  } elseif {$nextType ne "string"} {
    set err "Invalid string for $directive"
    lappend errors [makeError $filename $tokens $tokenNum $err]
    return [list {} {} $errors]
  }
  set charNums [stringToNums $nextValue]
  return [list $nextValue $charNums $errors]
}
