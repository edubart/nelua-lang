local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'

describe("utils", function()

it("fs.findmodulepath", function()
  local function assert_relative_findmodule(s, expected)
    expected = fs.abspath(expected)
    local neluapath = '/somedir/?.nelua;/somedir/?/init.nelua'
    local ok, _, triedpaths = fs.findmodule(s, neluapath, '.', 'nelua')
    assert(ok == expected or tabler.ifind(triedpaths, expected))
  end

  assert_relative_findmodule('test', '/somedir/test.nelua')
  assert_relative_findmodule('lib.test', '/somedir/lib/test.nelua')
  assert_relative_findmodule('test', '/somedir/test/init.nelua')
  assert_relative_findmodule('lib.test', '/somedir/lib/test/init.nelua')
  assert_relative_findmodule('/tmp/test.nelua', '/tmp/test.nelua')
  assert_relative_findmodule('./test.nelua', './test.nelua')
  assert_relative_findmodule('../test.nelua', '../test.nelua')
  assert_relative_findmodule('./test.nelua', './test.nelua')
  assert_relative_findmodule('.test', './test.nelua')
  assert_relative_findmodule('.lib.test', './lib/test.nelua')
  assert_relative_findmodule('..test', '../test.nelua')
  assert_relative_findmodule('..lib.test', '../lib/test.nelua')
  assert_relative_findmodule('...test', '../../test.nelua')
  assert_relative_findmodule('....test', '../../../test.nelua')
end)

it("tabler.shallow_compare_nomt", function()
  assert(tabler.shallow_compare_nomt({}, {}))
  assert(tabler.shallow_compare_nomt({a=1}, {a=1}))
  assert(not tabler.shallow_compare_nomt({a=1}, setmetatable({a=1}, {})))
  assert(not tabler.shallow_compare_nomt({a=1}, {a=2}))
  assert(not tabler.shallow_compare_nomt({a=1}, {a=1,b=2}))
end)

end)
