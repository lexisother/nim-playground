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

import macros


proc interpret*(code: string) =
  ## Interprets the Brainfuck `code` string, reading from stdin and writing to stdout.
  var
    tape = newSeq[char]()
    codePos = 0
    tapePos = 0

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

proc compile(code: string): NimNode {.compiletime.} =
  var stmts = @[newStmtList()]

  template addStmt(text) =
    stmts[stmts.high].add parseStmt(text)

  addStmt "var tape: array[1_000_000, char]"
  addStmt "var tapePos = 0"

  for c in code:
    case c
    of '+': addStmt "xinc tape[tapePos]"
    of '-': addStmt "xdec tape[tapePos]"
    of '>': addStmt "inc tapePos"
    of '<': addStmt "dec tapePos"
    of '.': addStmt "stdout.write tape[tapePos]"
    of ',': addStmt "tape[tapePos] = stdin.readChar"
    of '[': stmts.add newStmtList()
    of ']':
      var loop = newNimNode(nnkWhileStmt)
      loop.add parseExpr("tape[tapePos] != '\\0'")
      loop.add stmts.pop
      stmts[stmts.high].add loop
    else: discard

  result = stmts[0]


macro compileString*(code: string) =
  ## Compiles the brainfuck `code` string into Nim code that reads from stdin
  ## and writes to stdout.
  compile code.strVal

macro compileFile*(filename: string) =
  ## Compiles the brainfuck code read from `filename` at compile time into Nim
  ## code that reads from stdin and writes to stdout.
  compile staticRead(filename.strVal)

when isMainModule:
  import docopt, tables
  proc mandelbrot = compileFile("../examples/mandelbrot.b")

  let doc = """
brainfuck

Usage:
  brainfuck mandelbrot
  brainfuck interpret [<file.b>]
  brainfuck (-h | --help)
  brainfuck (-v | --version)

Options:
  -h --help     Show this screen.
  -v --version  Show version.
  """

  let args = docopt(doc, version = "brainfuck 1.0")

  if args["mandelbrot"]:
    mandelbrot()

  elif args["interpret"]:
    let code = if args["<file.b>"]: readFile($args["<file.b>"])
              else: readAll stdin

    interpret(code)
