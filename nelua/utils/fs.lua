local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plpath = require 'pl.path'
local except = require 'nelua.utils.except'
local stringer = require 'nelua.utils.stringer'

local fs = {}

fs.join = plpath.join
fs.tryreadfile = plfile.read
fs.abspath = plpath.abspath
fs.getbasename = plpath.basename
fs.getpathdir = plpath.dirname
fs.getfiletime = plfile.modified_time
fs.isfile = plpath.isfile

function fs.ensurefilepath(file)
  local outdir = plpath.dirname(file)
  local ok, err = pldir.makepath(outdir)
  except.assertraisef(ok, 'failed to create path for file "%s": %s', err)
end

function fs.writefile(file, content)
  local ok, err = plfile.write(file, content)
  except.assertraisef(ok, 'failed to create file "%s": %s', file, err)
end

function fs.readfile(file)
  local content, err = plfile.read(file)
  return except.assertraisef(content, 'failed to read file "%s": %s', file, err)
end

function fs.getcachepath(infile, cachedir)
  local path = infile:gsub('%.[^.]+$','')
  path = plpath.relpath(path)
  path = path:gsub('%.%.[/\\]+', '')
  path = plpath.join(cachedir, path)
  path = plpath.normpath(path)
  return path
end

function fs.getdatapath(arg0)
  local path
  if arg0 then --luacov:disable
    path = fs.getpathdir(arg0)
    -- luarocks install, use the bin/../conf/runtime dir
    if fs.getbasename(path) == 'bin' then
      path = fs.join(fs.getpathdir(path), 'conf')
    end
  else --luacov:enable
    path = fs.getpathdir(fs.getpathdir(fs.getpathdir(fs.abspath(debug.getinfo(1).short_src))))
  end
  return path
end

function fs.getuserconfpath(filename)
  return plpath.expanduser(fs.join('~', '.config', 'nelua', filename))
end

function fs.findmodulefile(name, path)
  name = name:gsub('%.', plpath.sep)
  local paths = stringer.split(path, ';')
  for _,trypath in ipairs(paths) do
    trypath = trypath:gsub('%?', name)
    if plpath.isfile(trypath) then
      return fs.abspath(trypath)
    end
  end
end

return fs
