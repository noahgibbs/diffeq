def include_dir(directory)
  $:.unshift(directory) unless
    $:.include?(directory) || $:.include?(File.expand_path(directory))
end

include_dir File.dirname __FILE__
#include_dir File.join(File.dirname(__FILE__), "diffeq")

module DiffEQ
  VERSION = '0.0.4'
end

require "diffeq/expression_parser"
require "diffeq/simple_expression"
require "diffeq/integrator"
require "diffeq/adaptive"
require "diffeq/rkck"
require "diffeq/rkqs"
require "diffeq/variable"
require "diffeq/plottable"
require "diffeq/advancer"
