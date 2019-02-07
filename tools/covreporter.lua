local re = require 're'
local file = require 'pl.file'
local colors = require 'term.colors'

local function colored_percent(value)
  local colored_value
  if value == 100 then
    colored_value = colors.green(string.format('%.2f%%', value))
  else
    colored_value = colors.red(string.format('%.2f%%', value))
  end
  return colored_value
end

local function report_coverage(reportfile)
  reportfile = reportfile or 'luacov.report.out'
  local reportdata = file.read(reportfile)
  if not reportdata then
    error('no coverage report found')
  end
  local pat = re.compile([[
body    <- (!heading .)* heading {| line+ |} footer
footer  <- tbldiv {| 'Total' sp num num percent |} !.
heading <- '='+%s+'Summary'%s+'='+%s+'File'%s+'Hits'%s+'Missed'%s+'Coverage'%s+'-'+%s+
line    <- !tbldiv {| file num num percent |}
tbldiv  <- '-'+ sp
num     <- {[%d]+} -> tonumber sp
percent <- {[.%d]+} -> tonumber '%' sp
file    <- {[-/_.%w]+} sp
sp      <- %s+
]], {
  tonumber = tonumber
})

  local filelines, totalline = pat:match(reportdata)
  assert(filelines and totalline, 'failed to parse luacov report output')

  local total_coverage = totalline[3]
  print(colored_percent(total_coverage) .. ' coverage')

  if total_coverage < 100 then
    print('\nnot fully covered files:')
  end
  for _,fileline in ipairs(filelines) do
    local filename, coverage = fileline[1], fileline[4]
    if coverage < 100 then
      print(colored_percent(coverage) .. ' ' .. filename)
    end
  end

  return total_coverage == 100
end

return report_coverage
