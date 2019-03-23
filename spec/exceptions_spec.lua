require 'busted.runner'()

local assert = require 'spec.assert'
local except = require 'euluna.utils.except'

describe("Euluna exceptions should work for", function()

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
  assert(except.is_exception(e, 'MyError'))
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
  assert.has.errors(function()
    except.try(function()
      error('an error')
    end, function() return true end)
  end)
end)

it("ignore number errors", function()
  assert.has.errors(function()
    except.try(function()
      error(1)
    end, function() return true end)
  end)
end)

end)
