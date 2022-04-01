local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local expect = require 'spec.tools.expect'
local except = require 'nelua.utils.except'

describe("except", function()

it("raising strings", function()
  local e
  except.try(function()
    except.assertraise(false, 'an error')
  end, function(ee)
    e = ee
    return true
  end)
  assert(e and e:get_message() == 'an error')
end)

it("raising tables", function()
  local e
  except.try(function()
    except.assertraise(true, 'not happening')
    except.raise({message='an error'})
  end, function(ee)
    e = ee
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising something", function()
  local e
  except.try(function()
    except.raise({message='an error'})
  end, function(ee)
    e = ee
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising Exception", function()
  local e
  except.try(function()
    except.raise(except.Exception({message = 'an error'}))
  end, function(ee)
    e = ee
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("raising labeled Exception", function()
  local e
  except.try(function()
    except.raise(except.Exception({label = 'MyError'}))
  end, function(ee)
    e = ee
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
  end, function(ee)
    e = ee
    return true
  end)
  assert(e and e.message == 'an error')
end)

it("ignore errors", function()
  expect.fail(function()
    except.try(function()
      error('an error')
    end, function() return true end)
  end)
end)

it("ignore number errors", function()
  expect.fail(function()
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
  assert(not ok and tostring(e):match('an error'))
end)

end)
