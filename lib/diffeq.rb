def include_dir(directory)
  $:.unshift(directory) unless
    $:.include?(directory) || $:.include?(File.expand_path(directory))
end

include_dir File.dirname __FILE__
#include_dir File.join(File.dirname(__FILE__), "diffeq")

module DiffEQ
  VERSION = '0.0.3'
end

require "diffeq/simple_expression.rb"
require "diffeq/integrator.rb"
require "diffeq/adaptive.rb"
require "diffeq/rkck.rb"
require "diffeq/rkqs.rb"
require "diffeq/variable.rb"
require "diffeq/advancer.rb"
