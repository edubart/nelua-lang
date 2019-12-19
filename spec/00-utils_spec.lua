require 'busted.runner'()

local assert = require 'spec.tools.assert'
local except = require 'nelua.utils.except'
local bn = require 'nelua.utils.bn'

describe("Nelua exceptions should work for", function()

it("raising strings", function()
  local e
  except.try(function()
    except.assertraise(false, 'an error')
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e:get_message() == 'an error')
end)

it("raising tables", function()
  local e
  except.try(function()
    except.assertraise(true, 'not happening')
    except.raise({message='an error'})
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising something", function()
  local e
  except.try(function()
    except.raise({message='an error'})
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising Exception", function()
  local e
  except.try(function()
    except.raise(except.Exception({message = 'an error'}))
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising labeled Exception", function()
  local e
  except.try(function()
    except.raise(except.Exception({label = 'MyError'}))
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e.label == 'MyError' and e:get_message() == 'MyError')
  assert(except.isexception(e, 'MyError'))
end)

it("reraising", function()
  local e
  except.try(function()
    except.try(function()
      except.raise('an error')
    end, function() return false end)
  end, function(_e)
    e = _e
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("ignore errors", function()
  assert.has_error(function()
    except.try(function()
      error('an error')
    end, function() return true end)
  end)
end)

it("ignore number errors", function()
  assert.has_error(function()
    except.try(function()
      error(1)
    end, function() return true end)
  end)
end)

it("errors with __tostring metamethod", function()
  local ok, errmsg = pcall(function()
    except.try(function()
      error(setmetatable({}, {__tostring = function() return 'myerr' end}))
    end, function() return true end)
  end)
  assert(not ok and errmsg:match("^myerr"))
end)

it("raising in pcall", function()
  local ok, e = pcall(function()
    except.assertraise(false, 'an error')
  end)
  assert(tostring(e):match('uncaught exception'))
end)

it("big numbers", function()
  local n = bn.new
  assert.is.equal('0', n(0):todec())
  assert.is.equal('0', n(-0):todec())
  assert.is.equal('1', n(1):todec())
  assert.is.equal('-1',n(-1):todec())
  assert.is.equal('0.5', n(0.5):todec())
  assert.is.equal('-0.5', n(-0.5):todec())
  assert.is.equal('0.30000000000000004', n(.1+.2):todec())
  assert.is.equal('0.30000000000000002', (n(.1)+n(.2)):todec())
  assert.is.equal('0.3',(n('.1')+n('.2')):todec())
  assert.is.equal('1000', n(1000):todec(17))
  assert.is.equal('0.14285714285714285', (n(1)/ n(7)):todecsci(17))
  assert.is.equal('1.4285714285714285', (n(10)/ n(7)):todecsci(17))
  assert.is.equal('-0.14285714285714285', (n(-1)/ n(7)):todecsci(17))
  assert.is.equal('-1.4285714285714285', (n(-10)/ n(7)):todecsci(17))
  assert.is.equal('14.285714285714285', (n(100)/ n(7)):todecsci(17))
  assert.is.equal('-14.285714285714285', (n(-100)/ n(7)):todecsci(17))
  assert.is.equal('0.014285714285714285', (n('0.1')/ n(7)):todecsci(17))
  assert.is.equal('-0.014285714285714285', (n('-0.1')/ n(7)):todecsci(17))
  assert.is.equal('0.0001', n(0.0001):todecsci())
  assert.is.equal('1.0000000000000001e-05', n('0.00001'):todecsci())
  assert.is.equal('0.0001', n(0.0001):todecsci())
  assert.is.equal('1.4285714285714285e-05', (n(1) / n(70000)):todecsci())
  assert.is.equal('1.4285714285714285e-05', n(1 / 70000):todecsci())
end)

end)
