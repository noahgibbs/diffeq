require File.dirname(__FILE__) + '/test_helper.rb'

require "matrix"

class TestSimpleExpression < Test::Unit::TestCase
  include DiffEQ

  def setup
  end

  private

  def pretty_print_parse_tree(list)
    return "(nil)" if list.nil?
    return "'#{list}'" if list.kind_of?(String)
    return "#{list}f" if list.kind_of?(Float)
    return "#{list}i" if list.kind_of?(Fixnum)
    return "#{list}b" if list.kind_of?(Bignum)

    raise "Unknown type!" unless list.kind_of?(Array)

    inner = list.collect{|item| pretty_print_parse_tree(item)}.join(" / ")
    list.kind_of?(EPNode) ? "{ #{inner} }" : "[ #{inner} ]"
  end

  def parse_tree_eval_equal?(expression, parse_tree, vars = nil,
                             eval_result = nil)
    expr = SimpleExpression.new(expression)
    assert(parse_tree == expr.get_parse_tree,
	   "Wrong parse tree:  " +
	   "'#{pretty_print_parse_tree(expr.get_parse_tree)}' instead of" +
	   " '#{pretty_print_parse_tree(parse_tree)}'!")

    if eval_result
      value = expr.evaluate(vars)
      assert( ((value - eval_result) / eval_result).abs < 0.00001,
	     "Wrong value: #{value} instead of #{eval_result} evaluating " + 
	     "#{pretty_print_parse_tree(expr.get_parse_tree)}!" )
    end
  end

  def eval_as_constant(expression, value)
    expr = SimpleExpression.new(expression)
    tree = expr.get_parse_tree
    opt = tree.optimize
    assert((SimpleExpression.number?(opt) and (opt - value).abs <= 0.0001),
	   "'#{expression}' optimizes to " +
	   "'#{pretty_print_parse_tree(tree)}', not '#{value}'!")
  end

  public

  def test_operator_predicate()
    assert(SimpleExpression.operator?("+"))
    assert(SimpleExpression.operator?("^"))
    assert(!SimpleExpression.operator?("a"))
    assert(!SimpleExpression.operator?("7"))
    assert(!SimpleExpression.operator?(""))
    assert(!SimpleExpression.operator?(nil))
  end

  def test_function_predicate()
    assert(SimpleExpression.function?("sin"))
    assert(SimpleExpression.function?("tan"))
    assert(!SimpleExpression.function?("z"))
    assert(!SimpleExpression.function?("-"))
    assert(!SimpleExpression.function?("blah"))
    assert(!SimpleExpression.function?(""))
    assert(!SimpleExpression.function?(nil))
  end

  def test_number_predicate()
    assert(SimpleExpression.number?(7))
    assert(SimpleExpression.number?(74.5))
    assert(SimpleExpression.number?(-8.4))
    assert(SimpleExpression.number?(655532471))
    assert(!SimpleExpression.function?("7"))
    assert(!SimpleExpression.function?("-1.2"))
    assert(!SimpleExpression.function?(Vector[7]))
    assert(!SimpleExpression.function?(""))
    assert(!SimpleExpression.function?(nil))
  end

  def test_basic_expressions()
    expr_blank = SimpleExpression.new(nil)

    expr_0 = SimpleExpression.new("0")
    assert(expr_0.constant?, "zero is non-constant!")

    expr_var = SimpleExpression.new("variable")
    assert(expr_var.variables == [ "variable" ], "simple variables() fails!")
  end

  def test_unary()
    # Negation of constant
    parse_tree_eval_equal?("-4.0", [ "-", 4.0 ], {}, -4.0 )

    # Negation of constant with a space
    parse_tree_eval_equal?("- 4.0", [ "-", 4.0 ], {}, -4.0 )

    # Negation of a variable
    parse_tree_eval_equal?("-x", [ "-", "x" ], { "x" => -2 }, 2.0 )

    # Plus a variable
    parse_tree_eval_equal?("+x", [ "+", "x" ], { "x" => 3e4 }, 30000 )
  end

  def test_variables_func()
    # Check "variables" call
    expr_varstest = SimpleExpression.new("x * (y + (3 * z + 4 * x))")
    assert(expr_varstest.variables.sort == [ "x", "y", "z" ],
	   "Can't get dependent variables!")
  end

  def test_unary_order_of_ops()
    # Check negated variable with operators
    parse_tree_eval_equal?("x * -y + 3", [ "+", ["*", "x", ["-", "y"]], 3.0],
			   {"x" => 7, "y" => -2}, 17)
  end

  def test_parens()
    # Check parens
    parse_tree_eval_equal?("3 + (47 * 9)",
			   [ "+", 3.0, [ "(", ["*", 47.0, 9.0], ], ],
			   {}, 426)

    # Check curly braces
    parse_tree_eval_equal?("3 + {47 * 9}",
			   [ "+", 3.0, [ "{", ["*", 47.0, 9.0], ], ],
			   {}, 426 )

    # Check square braces
    parse_tree_eval_equal?("3 + [47 * 9]",
			   [ "+", 3.0, [ "[", ["*", 47.0, 9.0], ], ],
			   {}, 426 )
  end

  def test_functions()
    # Check functions
    parse_tree_eval_equal?("sin(x)", ["sin", [ "(", "x" ] ],
			   { "x" => Math::PI/2 }, 1.0 )

    # Check function in expression
    parse_tree_eval_equal?("3*cos(4x)",
			   ["*", 3.0, [ "cos", [ "(", [ "*", 4.0, "x" ] ] ] ],
			   { "x"=> Math::PI/4 }, -3.0 )
  end

  def test_exponents()
    # Order of operations
    parse_tree_eval_equal?("x^y * x^z * y^z",
			   [ "*", [ "*", [ "^", "x", "y" ],
			       [ "^", "x", "z" ] ],
			     [ "^", "y", "z" ] ],
			   { "x" => 4, "y" => 2, "z" => 3 }, 16 * 64 * 8 )

    # Check exponentiating
    parse_tree_eval_equal?("3^x", [ "^", 3.0, "x" ], { "x" => 5 }, 243)

    # Check exponential order of ops
    parse_tree_eval_equal?("3^x^y", [ "^", 3.0, [ "^", "x", "y" ] ],
			   { "x" => 2, "y" => 3 }, 6561 )
  end

  def test_optimize_constants()
    eval_as_constant("-4.0", -4.0)
  end

end
