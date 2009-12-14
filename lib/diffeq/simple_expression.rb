#
# SimpleExpression gem
#
# (C) 2007-2009 Noah Gibbs
#

$:.unshift File.dirname(__FILE__)

module DiffEQ

class SimpleExpression
  def initialize(arg)
    if arg.kind_of?(String)
      @expression = arg
      arg = expression_from_string(arg)
    else
      @expression = "(not given)"
    end

    unless [EPNode, NilClass].include?(arg.class)
      raise "Arg must be string or parse tree, not '#{arg.class}'!"
    end

    @parse_tree = arg
    @variables = SimpleExpression.vars_from_parse_tree(@parse_tree)
    @constant = @variables.empty?
  end

  # Evaluate the expression using the specified variables.  Every
  # variable used in the expression must have a value in the supplied
  # hash table.
  #
  def evaluate(vars={})
    if (vars == nil or vars == {}) and not @constant
      raise "Must pass variables to evaluate non-constant expression!"
    end
    vars = {} if vars.nil?

    vars_keys = vars.keys
    @variables.each do |key|
      raise "No value for var #{key}!" unless vars.include?(key)
    end

    return @parse_tree if SimpleExpression.number?(@parse_tree)

    unless @parse_tree.kind_of?(EPNode)
      raise "Internal error: int. obj is '#{@parse_tree.class}', " +
	"not parse tree!"
    end

    @parse_tree.eval(vars)
  end

  # Return a SimpleExpression which is an optimized version of this
  # one.  The level of optimization is not guaranteed :-)
  #
  def optimize(vars={})
    opt_tree = @parse_tree.optimize(vars)
    SimpleExpression.new(opt_tree)
  end

  # Return the parse tree for this expression.
  #
  def get_parse_tree()
    return @parse_tree.dup  # copy parse tree so it can't be changed
  end

  # Return true if the string given is a legal variable name.
  #
  def self.legal_variable_name?(name)
    return true if (name =~ /^([_A-Za-z][_A-Za-z0-9]*)$/)
    false
  end

  # Return true if this expression is empty.  Usually 'empty' means
  # it was initialized with a nil or an empty string.
  #
  def empty?()
    not @parse_tree or @parse_tree.length == 0
  end

  # Return the set of variables referenced in the expression.  Returns an
  # empty list if no other variables are referenced.
  #
  def variables()
    return @variables
  end

  # Returns true if the variable references no other variables.  If
  # this function returns true then the expression may be evaluated
  # without passing any values as parameters to @evaluate@.
  #
  def constant?()
    return @constant
  end

end # class SimpleExpression

end # module DiffEQ
