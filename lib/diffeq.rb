$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module DiffEQ
  VERSION = '0.0.2'
end

require "diffeq/simple_expression.rb"
