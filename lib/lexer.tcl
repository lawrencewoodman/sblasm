# SUBLEQ Lexer routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# src is a list of lines
# A token is {type value lineNum}
# Returns {tokens symbols errors}
xproc::proc lex {filename src} {
  set src [split $src "\n"]
  set tokens [list]
  set symbols [dict create]
  set errors [list]
  set lineNum 1

  foreach line $src {
    set linePos 0
    set numLineTokens 0
    while {$linePos < [string length $line]} {
      set restLine [string range $line $linePos end]
      switch -regexp -matchvar matches -indexvar indices -- $restLine {
        {^\s+} {
          # Whitespace
          incr linePos [lindex [lindex $indices 0] 1]
        }
        {^\.[a-zA-Z][a-zA-Z_0-9]*(\s+|$)} {
          # Assembler directive
          set directive [string trimright [lindex $matches 0]]
          lappend tokens [list directive $directive $lineNum]
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^"([^\\"]|\\.)*"(\s+|$)} {
          # String
          if {$numLineTokens == 0} {
            set err [dict create filename $filename \
                                 lineNum $lineNum line $line \
                                 msg "Invalid position for string"]
            lappend errors $err
          } else {
            set str [string trimright [lindex $matches 0]]
            set str [string range $str 1 end-1]
            lappend tokens [list string $str $lineNum]
          }
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^[a-zA-Z][a-zA-Z_0-9:]*:(\s+|$)} {
          # Label
          if {$numLineTokens != 0} {
            set err [dict create filename $filename \
                                 lineNum $lineNum line $line \
                                 msg "Invalid position for label"]
            lappend errors $err
          } else {
            set label [string trimright [lindex $matches 0]]
            if {[string match {*::} $label] || [string match {*:::*} $label]} {
              set err [dict create filename $filename \
                                   lineNum $lineNum line $line \
                                   msg "Invalid label: $label"]
              lappend errors $err
            } else {
              set label [string trimright $label ":"]
              lappend tokens [list label $label $lineNum]
            }
          }
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^[a-zA-Z0-9:$]+[+-]+[$a-zA-Z0-9()+\-:]+(\s+|$)} {
          # Expression
          if {$numLineTokens == 0} {
            set err [dict create filename $filename \
                                 lineNum $lineNum line $line \
                                 msg "Invalid position for expression"]
            lappend errors $err
          } else {
            set expr [string trim [lindex $matches 0]]
            lappend tokens [list expr $expr $lineNum]
          }
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^[a-zA-Z$][$a-zA-Z0-9_:]*(\s+|$)} {
          # Identifier
          set id [string trimright [lindex $matches 0]]
          lappend tokens [list id $id $lineNum]
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^[-]?[0-9]+(\s+|$)} {
          # Number
          if {$numLineTokens == 0} {
            set err [dict create filename $filename \
                                 lineNum $lineNum line $line \
                                 msg "Invalid position for number"]
            lappend errors $err
          } else {
            set num [string trim [lindex $matches 0]]
            lappend tokens [list num $num $lineNum]
          }
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^#[-]?[0-9]+(\s+|$)} {
          # Literal
          if {$numLineTokens == 0} {
            set err [dict create filename $filename \
                                 lineNum $lineNum line $line \
                                 msg "Invalid position for literal"]
            lappend errors $err
          } else {
            set lit [string trim [lindex $matches 0]]
            set litVal [string trimleft $lit "#"]
            dict set symbols $lit [dict create type literal val $litVal]
            lappend tokens [list literal $lit $lineNum]
          }
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        {^;.*$} {
          # Comment
          set comment [string trim [string range [lindex $matches 0] 1 end]]
          lappend tokens [list comment $comment $lineNum]
          incr linePos [lindex [lindex $indices 0] 1]
          incr numLineTokens
        }
        default {
          # TODO: Better error message?
          set err [dict create filename $filename \
                               lineNum $lineNum line $line \
                               msg "Syntax error"]
          lappend errors $err
          set linePos [string length $line]
        }
      }
      incr linePos
    }
    if {$numLineTokens >= 1} {
      lappend tokens [list EOL "" $lineNum]
    }
    incr lineNum
  }
  if {[llength $errors] > 0} {set tokens {}}
  # TODO: Add sble token
  return [list $tokens $symbols $errors]
}


proc lexExpr {expr} {
  set tokens [list]
  set exprPos 0
  set expr [string trim $expr "{}"]
  while {$exprPos < [string length $expr]} {
    set restExpr [string range $expr $exprPos end]
    switch -regexp -matchvar matches -indexvar indices -- $restExpr {
      {^[+\-/*()]} {
        # Operator
        lappend tokens [list operator [lindex $matches 0]]
        incr exprPos
      }
      {^#[-]?[0-9]+} {
        # Literal
        lassign [lindex $indices 0] start end
        lappend tokens [list literal [lindex $matches 0]]
        incr exprPos [expr {$end+1}]
      }
      {^[A-Za-z_:][A-Za-z0-9_:]*} {
        # Label
        lassign [lindex $indices 0] start end
        lappend tokens [list label [lindex $matches 0]]
        incr exprPos [expr {$end+1}]
      }
      {^\$} {
        # Current position
        lappend tokens [list label $]
        incr exprPos
      }
      {^[0-9]+} {
        # Number
        lassign [lindex $indices 0] start end
        lappend tokens [list num [lindex $matches 0]]
        incr exprPos [expr {$end+1}]
      }
      default {
        set exprPos [string length $expr]
        # TODO: Test invalid expr
        return -code error "syntax error, expr: $expr"
      }
    }
  }
  return $tokens
}
