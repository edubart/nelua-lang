require 'busted.runner'()

local assert = require 'spec.tools.assert'
local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'

describe("Nelua utils should work for", function()

it("fs.findmodulepath", function()
  local function assert_relative_findmodule(s, expected)
    expected = fs.abspath(expected)
    local neluapath = '/somedir/?.nelua;/somedir/?/init.nelua'
    local ok, err, triedpaths = fs.findmodulefile(s, neluapath, '.')
    assert(ok == expected or tabler.ifind(triedpaths, expected))
  end

  assert_relative_findmodule('test', '/somedir/test.nelua')
  assert_relative_findmodule('lib.test', '/somedir/lib/test.nelua')
  assert_relative_findmodule('test', '/somedir/test/init.nelua')
  assert_relative_findmodule('lib.test', '/somedir/lib/test/init.nelua')
  assert_relative_findmodule('/tmp/test.nelua', '/tmp/test.nelua')
  assert_relative_findmodule('./test.nelua', './test.nelua')
  assert_relative_findmodule('../test.nelua', '../test.nelua')
  assert_relative_findmodule('./test', './test.nelua')
  assert_relative_findmodule('./test', './test/init.nelua')
  assert_relative_findmodule('../test', '../test.nelua')
  assert_relative_findmodule('../test', '../test/init.nelua')
  assert_relative_findmodule('.test', './test.nelua')
  assert_relative_findmodule('.lib.test', './lib/test.nelua')
  assert_relative_findmodule('..test', '../test.nelua')
  assert_relative_findmodule('..lib.test', '../lib/test.nelua')
  assert_relative_findmodule('...test', '../../test.nelua')
  assert_relative_findmodule('....test', '../../../test.nelua')
end)

end)
