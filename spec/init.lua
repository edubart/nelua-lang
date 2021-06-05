local lester = require 'nelua.thirdparty.lester'

lester.seconds = require 'nelua.utils.nanotimer'.nanotime

require 'spec.except_spec'
require 'spec.bn_spec'
require 'spec.pegger_spec'
require 'spec.utils_spec'
require 'spec.aster_spec'
require 'spec.syntaxdefs_spec'
require 'spec.typechecker_spec'
require 'spec.luagenerator_spec'
require 'spec.cgenerator_spec'
require 'spec.preprocessor_spec'
require 'spec.stdlib_spec'
require 'spec.runner_spec'

lester.report()
lester.exit()
