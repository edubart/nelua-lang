require 'busted.runner'()

local assert = require 'spec.tools.assert'

describe("Nelua stdlib", function()

it("cmath", function() assert.run_c([[
## strict = true

require 'C.math'

assert(C.fabs(-1.0) == 1.0)
assert(C.fabsf(-2.0_f32) == 2.0_f32)
assert(C.fabsl(-3.0_clongdouble) == 3.0_clongdouble)

assert(C.isnan(C.NAN))
assert(C.isinf(C.INFINITY))
assert(C.NAN ~= C.NAN)
]])end)

it("math", function() assert.run_c([[
## strict = true

require 'math'

local function asserteq(x: number, y: number)
  assert(math.abs(x - y) < 1e-12)
end

local e !compconst = 2.718281828459045
asserteq(math.abs(-1.0), 1)
asserteq(math.abs(1.0), 1)
asserteq(math.ceil(0.1), 1)
asserteq(math.ceil(1.0), 1)
asserteq(math.floor(0.9), 0)
asserteq(math.floor(0.0), 0)

asserteq(math.min(1.0, -1.0), -1)
asserteq(math.min(-1.0, 1.0), -1)
asserteq(math.max(1.0, -1.0), 1)
asserteq(math.max(-1.0, 1.0), 1)
assert(math.min(math.huge, -math.huge) == -math.huge)
assert(math.max(math.huge, -math.huge) == math.huge)

asserteq(math.acos(-1.0), math.pi)
asserteq(math.acos(1.0), 0)
asserteq(math.asin(0.0), 0)
asserteq(math.asin(1.0), math.pi/2)
asserteq(math.atan(0.0), 0)
asserteq(math.atan(1.0), math.pi/4)
asserteq(math.atan2(0.0, 1.0), 0)
asserteq(math.atan2(0.0, -1.0), math.pi)

asserteq(math.cos(math.pi), -1)
asserteq(math.cos(0.0), 1)
asserteq(math.sin(math.pi/2), 1)
asserteq(math.sin(0.0), 0)
asserteq(math.tan(math.pi/4), 1)
asserteq(math.tan(0.0), 0)

asserteq(math.deg(math.pi / 2), 90)
asserteq(math.deg(0), 0)
asserteq(math.rad(90), math.pi / 2)
asserteq(math.rad(0), 0)

asserteq(math.sqrt(4.0), 2)
asserteq(math.sqrt(9.0), 3)
asserteq(math.exp(0), 1)
asserteq(math.exp(1), e)
asserteq(math.log(1), 0)
asserteq(math.log(e), 1)
asserteq(math.logbase(1, 2), 0)
asserteq(math.logbase(2, 2), 1)
asserteq(math.logbase(1, 10), 0)
asserteq(math.logbase(10, 10), 1)

asserteq(math.fmod(5, 2), 1)
asserteq(math.fmod(2.3, 5.7), 2.3)

do
  local i: number, f: number
  i, f = math.modf( 5.0)  asserteq(i, 5)  asserteq(f, 0.0)
  i, f = math.modf( 5.3)  asserteq(i, 5)  asserteq(f, 0.3)
  i, f = math.modf(-5.3)  asserteq(i,-5)  asserteq(f,-0.3)
end

assert(not (math.maxinteger < math.mininteger))
assert(math.ult(math.maxinteger, math.mininteger))
assert(math.tointeger(1.0) == 1_integer)
assert(math.type(1.0) == 'float')

math.randomseed(0)

do
  for i=1,10 do
    local x: number = math.random()
    assert(x >= 0 and x <= 1)
  end
end

]])end)

it("os", function() assert.run_c([[
## strict = true

require 'os'

assert(os.clock() >= 0)
assert(os.difftime(0,0) == 0 and os.difftime(0,1) == 1)
--print(os.date())
assert(type(os.getenv('PATH')) == 'string')
assert(type(os.tmpname()) == 'string')
assert(os.execute_check() == true)
--assert(os.execute('my_invalid_command'))
assert(os.rename('my_invalid_file', 'my_invalid_file') == false)
assert(os.remove('my_invalid_file') == false)
assert(os.setlocale_default('C') == 'C')
assert(os.setlocale('C','numeric') == 'C')
assert(os.time_default() >= 0)
os.exit(0)
os.exit_boolean(true)
os.exit_default()
assert(false)

]])end)

it("memory", function() assert.run_c([[
## strict = true

require 'memory'

local function assertmem(s: span<byte>, x: byte)
  for i=0_usize,<s.size do
    assert(s[i] == x)
  end
end

local mem = memory.alloc(4)
assert(mem.size == 4)
assertmem(mem, 0)

memory.realloc(mem, 8)
assert(mem.size == 8)
assertmem(mem, 0)

memory.set(mem, 0xff)
assertmem(mem, 0xff)

memory.dealloc(mem)
assert(mem.size == 0)

]])end)

end)
