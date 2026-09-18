vim9script

# Minimal BDD DSL for the keyhabits specs.
#
# Vim under -es does not send :echo to stdout, but :verbose echo writes
# straight to fd 1, which also works when stdout is a pipe or a socket.

var passed: number = 0
var failed: number = 0
var depth: number = 0

def Say(line: string)
  verbose echo line
enddef

def Pad(): string
  return repeat('  ', depth)
enddef

def CleanException(exception: string): string
  var marker: number = stridx(exception, '):')
  if strpart(exception, 0, 4) == 'Vim(' && marker > 0
    return strpart(exception, marker + 2)
  endif
  return exception
enddef

export def Describe(name: string, Body: func())
  Say(Pad() .. name)
  depth += 1
  try
    Body()
  finally
    depth -= 1
  endtry
enddef

export def It(name: string, Body: func())
  try
    Body()
    passed += 1
    Say(Pad() .. 'ok ' .. name)
  catch
    failed += 1
    Say(Pad() .. 'FAIL ' .. name .. ': ' .. CleanException(v:exception))
  endtry
enddef

export class Expectation
  var actual: any

  def new(this.actual)
  enddef

  def _Fail(message: string)
    throw 'Expect: ' .. message
  enddef

  def ToEqual(expected: any)
    if this.actual != expected
      this._Fail($'expected {string(expected)} but got {string(this.actual)}')
    endif
  enddef

  def NotToEqual(expected: any)
    if this.actual == expected
      this._Fail($'expected {string(this.actual)} not to equal {string(expected)}')
    endif
  enddef

  def ToBeTrue()
    if this.actual != true
      this._Fail($'expected true but got {string(this.actual)}')
    endif
  enddef

  def ToBeFalse()
    if this.actual != false
      this._Fail($'expected false but got {string(this.actual)}')
    endif
  enddef

  def ToContain(item: any)
    if type(this.actual) == v:t_list
      if index(this.actual, item) < 0
        this._Fail($'expected {string(this.actual)} to contain {string(item)}')
      endif
      return
    endif
    if type(this.actual) == v:t_string
      var needle: string = type(item) == v:t_string ? item : string(item)
      if stridx(this.actual, needle) < 0
        this._Fail($'expected {string(this.actual)} to contain {string(needle)}')
      endif
      return
    endif
    this._Fail($'expected a list or a string but got {string(this.actual)}')
  enddef

  def ToHaveLength(n: number)
    if len(this.actual) != n
      this._Fail($'expected length {n} but got {len(this.actual)}')
    endif
  enddef

  def ToThrow(pattern: string)
    if type(this.actual) != v:t_func
      this._Fail($'expected a func but got {string(this.actual)}')
      return
    endif
    var Throwing: func = this.actual
    try
      Throwing()
    catch
      var reason: string = CleanException(v:exception)
      if reason =~ pattern
        return
      endif
      this._Fail(
        $'expected an exception matching {string(pattern)} but got {string(reason)}')
    endtry
    this._Fail(
      $'expected an exception matching {string(pattern)} but nothing was thrown')
  enddef
endclass

export def Expect(actual: any): Expectation
  return Expectation.new(actual)
enddef

export def Summary(): dict<number>
  return {passed: passed, failed: failed}
enddef
