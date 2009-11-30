require "simpleexpression"
require "log4r"
require "yaml"

module DiffEQ

# Set VarSet objects up for YAML input and output
# Still needed?
VarObjectDomain = "!github_diffeq_gem,2009-11-29"
YAML.add_domain_type(VarObjectDomain, "varset") { |type, val|
  YAML.object_maker(VarSet, val)
}

class VarSet
  include Log4r

  def to_yaml_type
    VarObjectDomain + "/varset"
  end

  private

  def initialize()
    @var_set = {}

    print "Starting Logger initialization!\n"
    diffeq_logger = Logger['diffeq']
    diffeq_logger = Logger.new 'diffeq' unless diffeq_logger
    diffeq_logger.outputters = Outputter.new 'delogfile',
                                        :filename => 'diffeq.log', :trunc => 0
    #diffeq_logger.outputters = Outputter.stderr

    @logger = diffeq_logger
  end

  public

  # Add a variable by name and value, where value should be a string
  # denoting the value.  Returns a DiffEQ::Variable object.
  #
  def add_variable(name, value)
    if @var_set[name]
      raise "Variable '#{name}' already exists!"
    end

    if value.kind_of?(Variable)
      newvar = value
    else
      newvar = Variable.new(name, value, self)
    end

    @logger.debug("Adding variable '#{name}', value '#{value}'\n")

    @var_set[name] = newvar
  end

  # Add a variable with a value, but only if there is no variable that
  # yet has that name.
  #
  def add_variable_if_unset(name, value)
    unless @var_set[name]
      add_variable(name, value)
    end
    @var_set[name]
  end

  # Queries a variable by name.  Returns the Variable for that name.
  #
  def variable_by_name(name)
    @var_set[name]
  end

  # Iterates through all registered variables.  The block's argument
  # is a Variable object.
  #
  def each_variable()
    @var_set.values.each { |var| yield(var) }
  end

  # Returns a list of all registered variable names.
  #
  def variable_names()
    @var_set.keys
  end

  # Returns a list of all registered Variable objects.
  #
  def variable_objects()
    @var_set.values
  end

  # Converts the variable set to a YAML array
  #
  def to_yaml()
    @var_set.values.to_yaml
  end

end

class Variable
  attr_reader :name, :value, :value_string, :parent

  VARIABLE_TYPES = [ :Simple, :DiffEQ, :NoInfo, :Derived, :Searching ]

  include Log4r

  def initialize(name, value, parent)
    @logger = Logger['diffeq']

    Variable.legal_name?(name) or
      raise "Illegal variable name '#{name}'!"
    @name = name

    set_value(value)

    @known = []
    @parent = parent
    @index = nil
  end

  # Set the value of this variable to the string given, which
  # should parse into an appropriate mathematical expression.
  #
  def set_value(value)
    unless value.kind_of?(String) or value == nil
      raise "Illegal value passed to set_value!"
    end

    @value = nil
    @value_string = value
    if value and value != ""
      @value = SimpleExpression.new(value)
    end

    @vartype = nil
    @depends_on = nil
    @diffeq_deps = nil
  end

  # Display the variable as a simple string.
  #
  def to_s
    "Variable: #{@name}(t) = '#{@value}'"
  end

  # Add a point at which the variable's value is known.
  #
  def add_known(time, value)
    @known += [ [ time, value ] ]
  end

  # Return a Hash of all known values at given times
  #
  def get_all_known()
    return @known.dup
  end

  # Return known value, if any, for a given time
  #
  def get_known_at_approx(x, epsilon=0.01)
    @known.each do |time, value|
      return value if (time - x).abs < epsilon
    end
    nil
  end

  # Set the index of this variable for DiffEQ calculation.
  #
  def index=(idx)
    raise "Index already set!" unless @index.nil?
    @index = idx
  end

  # Retrieve the index of this variable in DiffEQ calculation.
  #
  def index
    @index
  end

  # Clear this index, it's no longer needed for DiffEQ calculation.
  #
  def clear_index
    @index = nil
  end

  # Query whether the variable is a constant (i.e. depends on no other
  # variables).  Returns true or false.
  #
  def constant?
    @value.constant?
  end

  # Evaluate the variable with a given set of other values as
  # context.  The value t is the time variable.
  #
  def evaluate(t, vars)
    raise "Unknown value!" if @value.nil? or @value == ""
    raise "Not enough information!" if @vartype == :NoInfo
    raise "Must pass a table of variable values to evaluate non-constant " +
      "variable #{@name}!" if (vars.nil? or vars == {}) and
        not @value.constant?

    @value.evaluate(vars)
  end

  # Returns a list of the other Variables that this object
  # depends on.  This is set from the variable's value expression.
  #
  def depends_on()
    if @value.nil?
      return []
    end
    unless @depends_on
      @depends_on = @value.variables.collect do |var|
	tmp = @parent.variable_by_name(var)
	tmp or raise "Can't locate variable dependency '#{var}'!"
      end
    end
    @depends_on
  end

  # Returns a list of all the other Variables that this object
  # and its first derivative depend on.  This is set from the variable's
  # value expression and the value expression of its first derivative.
  #
  def diffeq_depends_on()
    unless @diffeq_deps
      my_deps = depends_on  # calculate @depends_on

      d1_name = Variable.derivative_of_name(@name)
      my_d1 = @parent.variable_by_name(d1_name)
      d1_deps = my_d1.depends_on

      @diffeq_deps = my_deps | d1_deps
    end
    @diffeq_deps
  end

  # Queries whether the string given is a legal variable name.
  #
  def self.legal_name?(name)
    SimpleExpression.legal_variable_name?(name)
  end

  # Returns the name of the derivative (slope) variable for the
  # given variable.  This variable is not guaranteed to exist, but
  # if it does exist, will be treated as the derivative of the
  # given variable.
  #
  def self.derivative_of_name(name)
    matchobj = /^(.*)_D([0-9]+)$/.match(name)
    if(matchobj)
      return matchobj[1] + "_D#{matchobj[2].to_i + 1}"
    end

    name + "_D1"
  end

  private

  # This is syntactic sugar to get rid of error-prone repetition in
  # the variable_type() method.
  #
  def set_vartype(val)
    @vartype = val
    val
  end

  public

  # Returns the solution type of the variable.  This tells whether
  # the solver has a closed-form solution for the variable, has
  # to solve it with a numerical solver, or simply doesn't have
  # the information to know the variable's value.  Returns a symbol,
  # which will be a member of the VARIABLE_TYPES constant.
  #
  def variable_type(tentative_ok = false)
    return @vartype if @vartype

    @logger.debug("Starting var query on #{@name}...")

    if not @value or @value.empty?
      if @known.empty?
	# Need at least one known point or a value expression...
	@logger.debug(
	    "Variable #{@name} is empty with no known points.")
	return set_vartype(:NoInfo)
      end

      deriv_var_type = nil  # in case var is undefined
      deriv_name = Variable.derivative_of_name(@name)
      deriv_var = parent.variable_by_name(deriv_name)

      # Set to :Searching to avoid circular reference...
      @vartype = :Searching
      deriv_var_type = deriv_var.variable_type(tentative_ok) if deriv_var
      @vartype = nil

      if not deriv_var_type
	@logger.debug("Variable #{@name}'s derivative is undefined.")
	return set_vartype(:NoInfo)
      end

      if deriv_var_type == :NoInfo
	@logger.debug("Variable #{@name}'s derivative is unspecified.")
	return set_vartype(:NoInfo)
      end

      # If the deriv is anything other than "no info", we're a DiffEQ.
      # If it's :Searching, then there's info but there's also a
      # circular dependency, which is actually fine for a DiffEQ --
      # the next timestep's value depends on the current timestep, so
      # it only looks circular.
      if [:Simple, :DiffEQ, :Derived, :Searching].include?(deriv_var_type)
	@logger.debug(
            "Variable #{@name} has simple, diffeq or derived derivative.")
	return set_vartype(:DiffEQ)
      end

      raise "Logic isn't complete in variable_type!  Bad var type?"
    end

    if @value.constant?
      @logger.debug("Variable #{@name} is constant.")
      return set_vartype(:Simple)
    end

    depends_on()  # make sure it's calculated

    # Set type to :Searching here so that circular dependencies don't kill us
    @vartype = :Searching
    vartypes = @depends_on.collect { |var| var.variable_type(tentative_ok) }
    @vartype = nil

    if vartypes.include?(:NoInfo)
      @logger.debug("Variable #{@name} depends on a :NoInfo.")
      return set_vartype(:NoInfo)
    end

    if vartypes.include?(:DiffEQ)
      @logger.debug("Variable #{@name} depends on a DiffEQ.")
      return set_vartype(:Derived)
    end

    if vartypes.include?(:Derived)
      @logger.debug("Variable #{@name} depends on a Derived.")
      return set_vartype(:Derived)
    end

    if vartypes.include?(:Searching)
      @logger.debug("Variable #{@name} depends on a Searching!")
      return :Searching if tentative_ok
      raise "Variable #{@name} depends on unresolved variable!"
    end

    unless vartypes.all? { |type| type == :Simple }
      raise "Not all dependent types are simple!  Internal logic error!"
    end

    @logger.debug("Variable #{@name} defaults to :Simple.")
    return set_vartype(:Simple)
  end

end

# The TimeVariable is a special variable equal to the solver's time
# value.  It is special because it depends on time, but is still marked
# as :Simple.
#
class TimeVariable < Variable

  def initialize(name)
    super(name, nil, self)
    @vartype = :Simple
  end

  # Evaluate the time variable at the given time
  def evaluate(t, vars)
    t  # Right now, time vars must simply return t.
  end

end

end
