import os

let code = if paramCount() > 0: readFile paramStr(1)
else: readAll stdin

var
  tape = newSeq[char]()
  codePos = 0
  tapePos = 0

# In Nim 0.11 and above, the `inc` and `dec` procs for `char`s have
# under/overflow checks. This means that when we have the character `\0` and decrement it,
# we end up with a runtime error! Instead, in brainfuck, we want to wrap around
# and get `\255` instead. We cold use a `uint8` instead of a `char`, because unsigned ints
# wrap around in Nim. But then we have to convert that `uint8` to a `char` sometimes
# and the other way around. A more convenient way is to define our own, non-overflow-checking
# xinc and xdec procs:
{.push overflowchecks: off.}
proc xinc(c: var char) = inc c
proc xdec(c: var char) = dec c
{.pop.}

proc run(skip = false): bool =
  while tapePos >= 0 and codePos < code.len:
    if tapePos >= tape.len:
      tape.add '\0'

    if code[codePos] ==  '[':
      inc codePos
      let oldPos = codePos
      while run(tape[tapePos] == '\0'):
        codePos = oldPos
    elif code[codePos] == ']':
      return tape[tapePos] != '\0'
    elif not skip:
      case code[codePos]
      of '+': xinc tape[tapePos]
      of '-': xdec tape[tapePos]
      of '>': inc tapePos
      of '<': dec tapePos
      of '.': stdout.write tape[tapePos]
      of ',': tape[tapePos] = stdin.readChar
      else: discard

    inc codePos

discard run()