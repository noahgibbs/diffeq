#
# SimpleExpression library
# Copyright (C) 2007 Noah Gibbs
#

module DiffEQ

class EPNode < Array
  private

  def self.prveval(obj, vars, do_raise=true)
    return :NoInfo if obj == :NoInfo
    if SimpleExpression.number?(obj)
      return obj
    end
    if obj.kind_of?(String)
      return vars[obj] if vars[obj]
      raise "Unknown variable '#{obj}'!" if do_raise
      return :NoInfo
    end
    obj.eval(vars)
  end

  public

  # Evaluate this parse node and any appropriate child nodes.  It is
  # assumed that any appropriate variables are set in the vars parameter.
  #
  def eval(vars = {})
    args = self[1..-1].collect { |arg| EPNode.prveval(arg, vars) }
    op = self[0]

    return op if self.size == 1 && op.is_a?(Numeric)

    op = "**" if op == "^"  # exponentiation uses different op in ruby

    if SimpleExpression.operator?(op)
      if self.length == 2
        return (op == "-" ? -args[0] : args[0])
      elsif self.length == 3
        return (args[0]).send(op, args[1])
      else
        raise "Unexpected number of arguments to #{op}!"
      end
    end

    if SimpleExpression.function?(op)
      return Math.send(op, args[0])
    end

    return vars[op] if vars[op] && self.length == 1

    raise "Unknown variable #{op} in EPNode##eval!" if op.is_a?(String)

    raise "Unknown expression, #{op} / #{op.class} " +
      "len #{args.size}, in EPNode##eval!"
  end

  # Return an EPNode which is an optimized version of this one (plus
  # any appropriate child nodes).  Right now, we just do constant
  # folding.
  #
  def optimize(vars = {})
    args = self[1..-1].collect { |arg| EPNode.prveval(arg, vars, false) }
    if args.any? { |arg| arg == :NoInfo }
      opt = [ nil ] * args.length
      args.each_with_index do |arg, index|
        opt[index] = args[index]
        opt[index] = self[index + 1] if args[index] == :NoInfo
      end
      return EPNode.new(opt)
    end

    self.eval(vars)
  end
end

class SimpleExpression

  NUMBER_REGEXP = /^([-+0-9.]+(e[-+]?[0-9]+)?)(.*)$/
  OPERATORS = "-+/*()[]{}^"
  OPERATOR_REGEXP = Regexp.new("[#{Regexp.escape(OPERATORS)}]")
  FUNCLIST = ["sin", "cos", "tan"]
  PAREN_LIST = ["(", "[", "{"]

  # Returns true if the specified object is numeric
  #
  def self.number?(quantity)
    return true if quantity.kind_of?(Numeric)
    false
  end

  # Returns true if the specified string corresponds to a recognized
  # operator.  Note that numbers, functions and variables do not count
  # as operators.
  #
  def self.operator?(string)
    (string =~ OPERATOR_REGEXP) ? true : false
  end

  # Returns true if the specified string corresponds to a single
  # recognized function.  Note that numbers, operators and variables
  # do not count as functions.
  #
  def self.function?(string)
    FUNCLIST.include?(string)
  end

  def self.vars_from_parse_tree(tree) # :nodoc:
    var_table = {}

    token_iter(tree) do |item|
      var_table[item] = 1 if (SimpleExpression.legal_variable_name?(item) &&
        !SimpleExpression.function?(item))
    end

    return var_table.keys
  end

  protected

  def expression_from_string(string)
    raise "Not a string!" unless string.kind_of?(String)

    tokens = SimpleExpression.tokenize(string)

    tokens = SimpleExpression.group_parens(tokens, "(", ")")
    tokens = SimpleExpression.group_parens(tokens, "[", "]")
    tokens = SimpleExpression.group_parens(tokens, "{", "}")

    tokens = SimpleExpression.group_functions(tokens, FUNCLIST,
                                              PAREN_LIST)
    tokens = SimpleExpression.group_right_left(tokens, ["^"])
    tokens = SimpleExpression.group_unary(tokens, ["-", "+"])
    tokens = SimpleExpression.group_operands(tokens)
    tokens = SimpleExpression.group_left_right(tokens, ["*", "/"])
    tokens = SimpleExpression.group_left_right(tokens, ["+", "-"])
    tokens = SimpleExpression.unwrap_parens(tokens, PAREN_LIST)

    # If the outer layer is a single element array around an array,
    # upwrap it.
    if tokens.kind_of?(Array) && tokens.length == 1 && tokens[0].kind_of?(Array)
      tokens = tokens[0]
    end

    raise "Can't completely parse expression '#{string}'!" unless
      SimpleExpression.fully_parsed?(tokens)

    if not tokens.kind_of?(EPNode)
      # We already checked, via "fully_parsed?", that the length
      # of any non-EPNode Array was 1.
      raise "Internal error: wrong length!" unless tokens.length == 1

      tokens = EPNode.new(tokens)
    end

    unless tokens.class == EPNode
      raise "Internal error (#{arg.class} != EPNode)!"
    end

    tokens
  end

  public

  def self.tokenize(expression) #:nodoc:
    tokenlist = []
    current = ""

    raise "Not a string!" unless expression.kind_of?(String)

    if not expression or expression == ""
      return []
    end

    while expression != ""
      # Cut out whitespace
      if /\s/.match(expression[0..0])
        expression.sub!(/^\s+/, "")
        next
      end

      # Grab a variable name
      if expression[0..0] =~ /[A-Za-z]/
        matchobj = /^([A-Za-z][-_A-Za-z0-9]*)(.*)$/.match(expression)

        raise "Can't parse variable name in expression!" unless matchobj
        unless SimpleExpression.legal_variable_name?(matchobj[1])
          raise "Illegal var name"
        end

        tokenlist += [ matchobj[1] ]
        expression = matchobj[2]
        next
      end

      # Grab an operator symbol
      if expression[0..0] =~ OPERATOR_REGEXP
        tokenlist += [ expression[0..0] ]
        expression = expression [1, expression.size]
        next
      end

      # Grab a number
      if expression[0..0] =~ /[-+0-9.]/
        matchobj = NUMBER_REGEXP.match(expression)
        unless matchobj
          raise "Can't parse number in expression!"
        end
        num = matchobj[1].to_f()
        tokenlist += [ num ]
        expression = matchobj[3]
        next
      end

      raise "Untokenizable expression '#{expression}'!\n"
    end

    tokenlist
  end

  # If the argument is an array containing arrays, this will call the
  # provided block on each subarray.  It will take the array of return
  # values of the block, and call the block on that array again, and
  # return that value.
  #
  def self.grouping_iter(tokens, &myproc) #:nodoc:
    return [] if tokens.nil? or tokens.empty?
    tokenclass = tokens.class

    newtokens = tokens.collect do |token|
      token.kind_of?(Array) ? grouping_iter(token, &myproc) : token
    end

    # Preserve EPNode-ness
    tokenclass.new(myproc.call(tokenclass.new(newtokens)))
  end

  # Iterate over every token, changing nothing and returning nil.
  #
  def self.token_iter(tokens) #:nodoc:
    return if tokens.nil? or tokens.empty?

    grouping_iter(tokens) do |inner_tokens|
      inner_tokens.each do |token|
        yield(token)
      end
    end

    nil
  end

  # The full_grouping_pass function iterates over the entire parse
  # tree, examining unparsed sections and testing (with grouptestproc)
  # to see if they can be partially parsed.  If so, tokenchangeproc is
  # used to determine the new token string after replacement.
  #
  # grouptestproc - Takes a list of tokens, and the current parsing index
  #  ("cursor") within them.  Returns true to do a replacement at the
  #  current cursor, or false to push the current token unchanged to the
  #  output list and continue.
  # tokenchangeproc - If grouptestproc returns true, this is called on
  #  the old tokens, new tokens and current index to update the new tokens.
  # indexchangeproc - Takes the old tokens and index, and returns
  #   the new index after the change.  By default, the new index is the
  #   original index plus one.
  #
  def self.full_grouping_pass(tokens, grouptestproc, tokenchangeproc,
                 indexchangeproc = lambda { |_tokens, index| index + 1 } )
    return [] if tokens.nil? or tokens.empty?

    finaltokens = grouping_iter(tokens) { |inner_tokens|
      if inner_tokens == []
        []
      elsif parsed?(inner_tokens)
        inner_tokens
      else
        newtokens = [ ]
        index = 0

        while index < inner_tokens.length
          if grouptestproc.call(inner_tokens, index)
            newtokens = tokenchangeproc.call(inner_tokens, newtokens, index)
            raise "newToken procedure returned nil!" if newtokens.nil?
            index = indexchangeproc.call(inner_tokens, index)
          else
            newtokens += [ inner_tokens[index] ]
          end

          index += 1
        end

        newtokens
      end
    }
    finaltokens
  end

  # Group the given tokens by the specified paren types.  For instance,
  # open_paren might be an opening square-bracket and close_paren might
  # be a closing square-bracket.
  #
  def self.group_parens(alltokens, open_paren, close_paren) #:nodoc:
    group_stack = []
    savedindex = -1
    savedtokens = nil

    # savedindex is only used to make sure we haven't run off the end
    # of a long expression after an unterminated open-paren.  We save it
    # in each subexpression -- it can fail when we start a new subexpression
    # without finishing the old one, and then we check again at the very
    # end to make sure we caught any problem at the top level.

    # The group stack holds the outer expression while we're parsing an
    # inner one.  As a result, newtokens will often only hold the innermost
    # subexpression that we're currently working on.  When we hit an end
    # paren, we mark that subexpression as done, append it to the top of
    # the group stack, and restore that level to be newtokens again.

    # Naturally, that means that when we hit an open-paren, we stash the
    # current "newtokens" in the group stack and make a new empty newtokens
    # array to be the new (empty) innermost subexpression.

    rettokens = full_grouping_pass(alltokens,
                       proc { |tokens, index|
                         if savedindex >= index && group_stack != []
                           raise "Unmatched '#{open_paren}' in " +
                             "'#{tokens}' " +
                             "in group_parens!"
                         end
                         savedindex = index

                         (tokens[index] == open_paren) ||
                          (tokens[index] == close_paren)
                       },
                       proc { |tokens, newtokens, index|
                         rettokens = nil
                         if tokens[index] == open_paren
                           group_stack += [ newtokens ]
                           rettokens = []
                         end
                         if tokens[index] == close_paren
                           if group_stack == []
                             raise "Unmatched '#{close_paren}' parsing " +
                               "'#{tokens}' in group_parens!"
                           end
                           rettokens = group_stack[-1] +
                             [ EPNode.new([open_paren] + [ newtokens ]) ]
                           group_stack = group_stack[0..-2]
                         end

                         rettokens
                       },
                       proc { |tokens, index| index }
    )  # end full_grouping_pass()

    if group_stack != []
      raise "Unmatched '#{open_paren}' in '#{alltokens}' in group_parens!\n"
    end

    rettokens
  end

  # Take the parse_tree chunks inside parens and inline them in the
  # same chunk (EPNode) as the paren.  Thus, this parse tree:
  #   [ '(', [ '*', 7.0, 'x' ], ')' ]
  # becomes this one:
  #   [ '(', '*', 7.0, 'x', ')', ]
  #
  def self.unwrap_parens(tokens, paren_list) #:nodoc:
    grouping_iter(tokens) do |inner_tokens|
      if inner_tokens.length > 1 && paren_list.include?(inner_tokens[0])
        [ inner_tokens[0] ] + inner_tokens[1]
      else
        inner_tokens
      end
    end
  end

  # Group the given tokens so that a parenthesized expression after
  # a recognized function name (like 'sqrt' or 'sin') will become
  # a function call.
  #
  def self.group_functions(tokens, funclist, parenlist) #:nodoc:
    full_grouping_pass(tokens,
                       # test if we found a function call
                       proc { |inner_tokens, index|
                         # If we're at the end of the list, not a function call
                         if index == (inner_tokens.length - 1)
                           false
                         else
                           # If the current token is a function name and the
                           # next token is a parenthesized expression, we found
                           # a function call.
                           function?(inner_tokens[index]) &&
                             inner_tokens[index+1].kind_of?(Array) &&
                             parenlist.include?(inner_tokens[index + 1][0])
                         end
                       },
                       proc { |inner_tokens, newtokens, index|
                         newtokens + [ EPNode.new([ inner_tokens[index],
                                                    inner_tokens[index + 1] ]) ]
                       })
  end

  # Group expressions like '-x' or '-sin(y)' so that the leading minus
  # is recognized as meaning 'negate'.
  #
  def self.group_unary(tokens, oplist) #:nodoc:
    full_grouping_pass(tokens,
                       # test if we should group unary minus or plus
                       proc { |inner_tokens, index|
                         if index == (inner_tokens.length - 1)
                           false
                         else
                           oplist.include?(inner_tokens[index]) &&
                             operand?(inner_tokens[index + 1]) &&
                             (index == 0 or not operand?(inner_tokens[index - 1]))
                         end
                       },
                       proc { |inner_tokens, newtokens, index|
                         newtokens + [ EPNode.new([ inner_tokens[index],
                                                    inner_tokens[index + 1] ]) ]
                       })
  end

  # Group adjacent operands and treat it as meaning multiplication.
  #
  def self.group_operands(tokens) #:nodoc:
    full_grouping_pass(tokens,
                       # test if we should group two terms adjacent
                       proc { |inner_tokens, index|
                         if index == (inner_tokens.length - 1)
                           false
                         else
                           operand?(inner_tokens[index]) &&
                             operand?(inner_tokens[index + 1])
                         end
                       },
                       proc { |inner_tokens, newtokens, index|
                         newtokens + [ EPNode.new([ "*", inner_tokens[index],
                                                    inner_tokens[index + 1] ]) ]
                       })
  end

  # Reverse the parse tree, and specifically those parts of it which
  # are not yet parsed into EPNodes.
  #
  def self.parse_tree_reverse(tokens, oplist) #:nodoc:
    grouping_iter(tokens) do |list|
      operator?(list[0]) ? [ list[0] ] + list[1..-1].reverse : list.reverse()
    end
  end

  # Do a right-to-left grouping pass on the specified operators.
  #
  def self.group_right_left(tokens, oplist) #:nodoc:
    return [] if tokens.nil? or tokens.empty?

    newtokens = parse_tree_reverse(tokens, oplist)

    grouped_tokens = group_left_right(newtokens, oplist)

    finaltokens = parse_tree_reverse(grouped_tokens, oplist)
  end

  # Checks if something is a suitable operand for operators.
  #
  def self.operand?(token) #:nodoc:
    token.kind_of?(Array) ||
      SimpleExpression.number?(token) ||
      (SimpleExpression.legal_variable_name?(token) &&
       !SimpleExpression.function?(token))
  end

  # Do a left-to-right grouping pass on the specified operators.
  #
  def self.group_left_right(tokens, oplist) #:nodoc:
    full_grouping_pass(tokens,
                       # test if we should group around a binary op
                       proc { |inner_tokens, index|
                         if index == 0 || index == (inner_tokens.length - 1)
                           false
                         else
                           oplist.include?(inner_tokens[index]) &&
                             operand?(inner_tokens[index-1]) &&
                             operand?(inner_tokens[index + 1])
                         end
                       },
                       proc { |inner_tokens, newtokens, index|
                         popped_token = newtokens[-1]
                         newtokens = newtokens[0..-2]
                         newtokens + [ EPNode.new([ inner_tokens[index],
                                                    popped_token,
                                                    inner_tokens[index+1] ]) ]
                       })
  end

  # Returns whether the current EPNode is parsed yet or not.
  #
  def self.parsed?(tokens) #:nodoc:
    return true if tokens.nil? or tokens.empty?
    return true if tokens.length == 1
    return true if tokens.kind_of?(EPNode)

    false
  end

  # Returns whether the current EPNode and all subnodes are
  # parsed.
  #
  def self.fully_parsed?(tree) #:nodoc:
    parsed?(tree) &&
      tree.select{|item| item.kind_of?(Array) }.all?{|arr| fully_parsed?(arr)}
  end

end # class SimpleExpression

end # module DiffEQ
