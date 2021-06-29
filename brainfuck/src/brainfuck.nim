import macros, streams

proc readCharEOF*(input: Stream): char =
  result = input.readChar
  if result == '\0':
    result = '\255'

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

proc interpret*(code: string, input, output: Stream) =
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

proc interpret*(code, input: string): string =
  var outStream = newStringStream()
  interpret(code, input.newStringStream, outStream)
  result = outStream.data

proc interpret*(code: string) =
  interpret(code, stdin.newFileStream, stdout.newFileStream)


proc compile(code: string, input, output: string): NimNode {.compiletime.} =
  var stmts = @[newStmtList()]

  template addStmt(text) =
    stmts[stmts.high].add parseStmt(text)

  addStmt """
    when not compiles(newStringStream()):
      static:
        quit("Error: Import the streams modules to compile Brainfuck code", 1)
  """

  addStmt "var tape: array[1_000_000, char]"
  addStmt "var inpStream = " & input
  addStmt "var outStream = " & output
  addStmt "var tapePos = 0"

  for c in code:
    case c
    of '+': addStmt "xinc tape[tapePos]"
    of '-': addStmt "xdec tape[tapePos]"
    of '>': addStmt "inc tapePos"
    of '<': addStmt "dec tapePos"
    of '.': addStmt "outStream.write tape[tapePos]"
    of ',': addStmt "tape[tapePos] = inpStream.readCharEOF"
    of '[': stmts.add newStmtList()
    of ']':
      var loop = newNimNode(nnkWhileStmt)
      loop.add parseExpr("tape[tapePos] != '\\0'")
      loop.add stmts.pop
      stmts[stmts.high].add loop
    else: discard

  result = stmts[0]


macro compileString*(code: string, input, output: untyped) =
  ## Compiles the brainfuck code read from `filename` at compile time into Nim
  ## code that reads from the `input` variable and writes to the `output`
  ## variable, both of which have to be strings.
  result = compile($code,
    "newStringStream(" & $input & ")", "newStringStream()")
  result.add parseStmt($output & " = outStream.data")

macro compileString*(code: string) =
  ## Compiles the brainfuck `code` string into Nim code that reads from stdin
  ## and writes to stdout.
  echo code
  compile($code, "stdin.newFileStream", "stdout.newFileStream")

macro compileFile*(filename: string, input, output: untyped) =
  ## Compiles the brainfuck code read from `filename` at compile time into Nim
  ## code that reads from the `input` variable and writes to the `output`
  ## variable, both of which have to be strings.
  result = compile(staticRead(filename.strval),
    "newStringStream(" & $input & ")", "newStringStream()")
  result.add parseStmt($output & " = outStream.data")

macro compileFile*(filename: string) =
  ## Compiles the brainfuck code read from `filename` at compile time into Nim
  ## code that reads from stdin and writes to stdout.
  compile(staticRead(filename.strval),
    "stdin.newFileStream", "stdout.newFileStream")

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
