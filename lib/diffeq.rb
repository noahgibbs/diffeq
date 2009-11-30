$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

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
