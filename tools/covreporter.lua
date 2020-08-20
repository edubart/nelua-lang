local re = require 'nelua.thirdparty.relabel'
local colors = require 'nelua.utils.console'.colors

local function readfile(filename)
  local f = assert(io.open(filename,'r'))
  local res = assert(f:read('*a'))
  f:close()
  return res
end

local function colored_percent(value)
  local colored_value
  if value == 100 then
    colored_value = colors.green..string.format('%.2f%%', value)..colors.reset
  else
    colored_value = colors.red..string.format('%.2f%%', value)..colors.reset
  end
  return colored_value
end

local function report_coverage(reportfile)
  reportfile = reportfile or 'luacov.report.out'
  local reportdata = readfile(reportfile)
  if not reportdata then
    error('no coverage report found')
  end
  local pat = re.compile([[
body    <- {| sfile* |} summary
sfile   <- {| {:name: '' -> 'file' :} '='+%s+!'Summary'{:file: [-/_.%w]+ :}%s+'='+%nl (miss / sline / eline)* |}
miss    <- !div '*'+'0 '{[^%nl]+} %nl
sline   <- !div ' '* %d* ' '* {''} [^%nl]+ %nl
eline   <- [ ]* {''} %nl
div     <- '==='+%s+[-/_.%w]+%s+'==='+%nl
summary <- {| heading {| line+ |} footer |}
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

  local sources, summary = pat:match(reportdata)
  assert(sources and summary, 'failed to parse luacov report output')

  local filelines, totalline = summary[1], summary[2]
  local total_coverage = totalline[3]
  print(colored_percent(total_coverage) .. ' coverage')

  if total_coverage < 100 then
    print('\nNot fully covered files:')
  end
  for _,fileline in ipairs(filelines) do
    local filename, coverage = fileline[1], fileline[4]
    if coverage < 100 then
      print(colored_percent(coverage) .. ' ' .. filename)

      for _,source in ipairs(sources) do
        if source.file == filename then
          local last = nil
          for i,line in ipairs(source) do
            if line ~= '' then
              if last and last ~= i - 1 then
                print()
              end
              print(colors.cyan..string.format('%6d\t',i)..colors.reset..line)
              last = i
            end
          end
        end
      end
    end
  end

  return total_coverage == 100
end

return report_coverage
