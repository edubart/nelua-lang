-- LuaDiffer: A simple Lua diff library
--
-- This file returns a function that can be called on two strings to return a table
-- containing the details of the difference between them. Usage:
--     >> local diff = require("diff")
--     >> diff("hello\nworld", "hello\nWORLD\n!!!")
--     {{old="hello", old_first=1, old_last=1, new="hello\n", new_first=1, new_last=1},
--      {old="world", old_first=2, old_last=2, new="WORLD\n!!!", new_first=2, new_last=3}}
-- The returned diff table also has a diff:tostring() method on it that can be used to print
-- the diff in a human-readable form. See below for the tostring options.
--
-- This implementation uses the Hunt–McIlroy algorithm, and is inspired by Jason Orendorff's
-- lovely python implementation at: http://pynash.org/2013/02/26/diff-in-50-lines/
--
-- Copyright 2017 Bruce Hill
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--luacov:disable

local diff_mt = {__index={}}

-- ANSI color codes
local function color(n) return string.char(27)..("[%dm"):format(n) end
local COLORS = {green=color(32), red=color(31), bright=color(1), underscore=color(4), reset=color(0)}

-- Return a new diff as if it were a diff of strings, rather than tables.
diff_mt.__index.stringify = function(d, sep)
    if #d > 0 and type(d[1].old) == 'string' then return d end
    sep = sep or ", "
    local stringified = {}
    for i,chunk in ipairs(d) do
        stringified[i] = {
            old=table.concat(chunk.old,sep), old_first=chunk.old_first, old_last=chunk.old_last,
            new=table.concat(chunk.new,sep), new_first=chunk.new_first, new_last=chunk.new_last,
        }
    end
    return setmetatable(stringified, diff_mt)
end

-- With a diff, you can call diff:tostring{...} to tostring it out. The options available are:
--   color = (true/false), true by default, whether or not to print with colors.
--   context = <number>, how many lines of context to print around the diff, (default: infinite)
--   sep = <string>, the separator used for context (default: "\n")
--   numbers = (true/false), whether or not to print the (line) numbers where the chunks
--     came from in the input (default: false)
diff_mt.__index.tostring = function(d, options)
  local ss = {}
  options = options or {}
  if #d > 0 and type(d[1].old) == 'table' then
    d = d:stringify(options.sep)
  end
  local colors = (options.color ~= false) and COLORS or setmetatable({}, {__index=function() return "" end})
  local numbers = options.numbers or false
  local insert = table.insert
  local context_pattern = nil
  options.context = options.context or math.huge
  if options.context ~= 0 and options.context ~= math.huge then
    local sep = options.sep or "\n"
    local lines = ("[^"..sep.."]*"..sep):rep(options.context)
    context_pattern = ("^("..lines..").*"..sep.."("..lines..")$")
  end
  for i,chunk in ipairs(d) do
    if chunk.old == chunk.new then
      -- Unchanged
      local same = chunk.old
      if context_pattern then
        local before, after = same:match(context_pattern)
        if before and after then
          -- "\b" is used as a hack to make sure the ellipsis is unindented
          if i == 1 then same = "\b\b...\n"..after
          elseif i == #d then same = before.."\n\b\b..."
          else same = before.."\b\b...\n"..after end
        end
      end
      if not (options and options.context == 0) then
        insert(ss, (same
          :gsub("([^\n]*)\n", "  %1\n")
          :gsub('\n([^\n]+)$', "\n  %1\n")
          :gsub('^([^\n]+)$', "  %1\n")
        ))
      end
    else
      -- Changed
      if #chunk.old > 0 then
        if numbers then
          insert(ss, colors.underscore..colors.bright..colors.red..
              ("Old #%d-%d:\n"):format(chunk.old_first, chunk.old_last)..colors.reset)
        end
        insert(ss, colors.red..(chunk.old
          :gsub("([^\n]*)\n", "- %1\n")
          :gsub('\n([^\n]+)$', "\n- %1\n")
          :gsub('^([^\n]+)$', "- %1\n")
        )..colors.reset)
      end
      if #chunk.new > 0 then
        if numbers then
          insert(ss, colors.underscore..colors.bright..colors.green..
              ("New #%d-%d:\n"):format(chunk.new_first, chunk.new_last)..colors.reset)
        end
        insert(ss, colors.green..(chunk.new
          :gsub("([^\n]*)\n", "+ %1\n")
          :gsub('\n([^\n]+)$', "\n+ %1\n")
          :gsub('^([^\n]+)$', "+ %1\n")
        )..colors.reset)
      end
    end
  end
  return table.concat(ss)
end

-- Take two strings or tables, and return a table representing a chunk-by-chunk diff of the two.
-- By default, strings are broken up by lines, but the optional third parameter "sep" lets
-- you provide a different separator to break on.
-- The return value is a list of chunks that have .old, .new corresponding to the old and
-- new versions. For identical chunks, .old == .new.
-- A new line is appended to both inputs if not present (to fix issues with the algorithm)
local function diff(old, new, sep)
  local insert, concat = table.insert, table.concat
  local A, B, slice
  if type(old) == 'string' and type(new) == 'string' then
    -- Split into a table using sep (default: newline)
    sep = sep or "\n"
    A, B = {}, {}
    for c in old:gmatch("[^"..sep.."]*"..sep.."?") do insert(A, c) end
    for c in new:gmatch("[^"..sep.."]*"..sep.."?") do insert(B, c) end
    if A[#A] == '' then A[#A] = nil end
    if B[#B] == '' then B[#B] = nil end
    slice = function(X,start,stop) return concat(X,"",start,stop) end
  elseif type(old) == 'table' and type(new) == 'table' then
    A, B = old, new
    slice = function(X,start,stop)
      local s = {}
      for i=start,stop do s[#s+1] = X[i] end
      return s
    end
  else
    error("Two different types passed to diff: "..type(old).." and "..type(new))
  end

  -- Find the longest common subsequence between A[a_min..a_max] and B[b_min..b_max] (inclusive),
  -- and return (the starting position in a), (the starting position in b), (the length)
  local longest_common_subsequence = function(a_min,a_max, b_min,b_max)
    local longest = {a=a_min, b=b_min, length=0}
    local runs = {}
    for a = a_min, a_max do
      local new_runs = {}
      for b = b_min, b_max do
        if A[a] == B[b] then
          local new_run_len = 1 + (runs[b-1] or 0)
          new_runs[b] = new_run_len
          if new_run_len > longest.length then
            longest.a = a - new_run_len + 1
            longest.b = b - new_run_len + 1
            longest.length = new_run_len
          end
        end
      end
      runs = new_runs
    end
    return longest
  end

  -- Find *all* the common subsequences between A[a_min..a_max] and B[b_min..b_max] (inclusive)
  -- and put them into the common_subsequences table.
  local common_subsequences = {}
  local find_common_subsequences
  find_common_subsequences = function(a_min,a_max, b_min,b_max)
    -- Take a greedy approach and pull out the longest subsequences first
    local lcs = longest_common_subsequence(a_min,a_max, b_min,b_max)
    if lcs.length == 0 then return end
    find_common_subsequences(a_min, lcs.a - 1, b_min, lcs.b - 1)
    insert(common_subsequences, lcs)
    find_common_subsequences(lcs.a + lcs.length, a_max, lcs.b + lcs.length, b_max)
  end
  find_common_subsequences(1,#A, 1,#B)

  -- For convenience in iteration (this catches matching chunks at the end):
  insert(common_subsequences, {a=#A+1, b=#B+1, length=0})

  local chunks = setmetatable({}, diff_mt)
  local a, b = 1, 1
  for _,subseq in ipairs(common_subsequences) do
    if subseq.a > a or subseq.b > b then
      insert(chunks, {
          old=slice(A, a, subseq.a-1), old_first=a, old_last=subseq.a-1,
          new=slice(B, b, subseq.b-1), new_first=b, new_last=subseq.b-1})
    end
    if subseq.length > 0 then
      -- Ensure that the *same* table is used for .old and .new so equality checks
      -- suffice and you don't need to do element-wise comparisons.
      local same = slice(A, subseq.a, subseq.a+subseq.length-1)
      insert(chunks, {
          old=same, old_first=subseq.a, old_last=subseq.a+subseq.length-1,
          new=same, new_first=subseq.b, new_last=subseq.b+subseq.length-1})
    end
    a = subseq.a + subseq.length
    b = subseq.b + subseq.length
  end
  return chunks
end

--luacov:enable

return diff
