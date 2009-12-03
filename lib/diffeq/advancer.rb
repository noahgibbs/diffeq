# advancer.rb - this file handles the tie-in work between the symbolic
# algebra of the simpleexpression library and the numerical
# integration of the integrator library.

require "rubygems"
require "diffeq/integrator"
require "diffeq/rkqs"
require "diffeq/variable"
require "tsort"

module DiffEQ

class Advancer
  EPSILON = 0.001
  H_START = 0.1
  H_MIN = 0.0001

  attr_accessor :logger

  def initialize(varset)
    @logger ||= DiffEQ.shared_logger

    @calculated = nil
    @deriv_proc = proc { |x,y| raise "Need to call calculate() first!" }
    @yzero = nil
    @simple_deps = nil
    @derived_deps = nil
    @diffeqs = nil
    @varset = varset
    @use_plotter = false

    @integrator = Adaptive_Cash_Karp_RK45.new
  end

  def start_plotter
    @use_plotter = true
    set_plotter(true)

    datapoint(0.0, @yzero) if @calculated
  end

  def stop_plotter
    @use_plotter = false
    set_plotter(false)
  end

  def write_plotter_file(filename)
    plot_to_file(filename)
  end

  # Get the derivative function for numerical integration
  #
  def get_deriv()
    @deriv_proc
  end

  # Get the vector of current DiffEQ values
  #
  def get_yzero_values()
    @yzero
  end

  private

  def eval_table_vars(varlist, t, values) #:nodoc:
    varlist.each do |var|
      values[var.name] = var.evaluate(t, values)
    end

    values
  end

  public

  # Creates a Hash of variable values for the given time.  Take the
  # current time and a vector of current DiffEQ y values.  This is
  # used to calculate :Derived values and the like.
  #
  def yvec_to_value_table(t, yvec)
    raise "Haven't called calculate recently enough!" unless @calculated

    values = eval_table_vars(@simple_deps, t, {})
    @diffeqs.each do |var|
      values[var.name] = yvec[var.index]
    end
    values = eval_table_vars(@derived_deps, t, values)

    values
  end

  private

  # This function takes a hash table where each key is a node to
  # be topologically sorted, and each value is a list of the
  # form [dep1, dep2, dep3] of dependencies of the first value.
  # The returned list is the set of hash keys in topologically
  # sorted order.
  #
  def topsort_hash(hash) #:nodoc:
    ts = TSortable.new()
  
    hash.each_pair do |hash, val|
      ts[hash] = val
    end
  
    ts.tsort
  end

  public

  # Return the list of variables, sorted by their dependencies on each
  # other.  Varlist is a list of DiffEQ::Variable objects.
  #
  def depsort_variables(varlist)
    deps_tsort_hash = {}
    varlist.each do |var|
      deps_tsort_hash[var] = (var.depends_on) & varlist
    end
    topsort_hash(deps_tsort_hash)
  end

  private

  # It's possible for variables to be of tentative or undefined type early
  # on, and then to be classified only after other variable types are
  # known.  This function iterates until no new variable types are
  # discovered.
  #
  def sort_vars_by_type()
    vars_by_type = {}
    Variable::VARIABLE_TYPES.each { |type| vars_by_type[type] = [] }

    vars_to_check = @varset.variable_objects

    # Keep going until no new variables are classified in a given pass
    next_pass_list = []
    while(true)
      vars_to_check.each do |var|
        newtype = var.variable_type(true)  # call with tentative_ok
        if newtype == :Searching
          @logger.debug(
               "Variable #{var.name} is tentative, skipping for now")
          next_pass_list += [ var ]
        else
          @logger.debug(
              "Adding variable #{var.name} of type #{var.variable_type()}")
          vars_by_type[newtype] += [ var ]
        end
      end

      break if next_pass_list == []
      raise "Unbreakable circular dep!" if vars_to_check == next_pass_list
      vars_to_check = next_pass_list
      next_pass_list = []
    end
    vars_by_type
  end

  public

  # Calculate all appropriate internal variables for the current defined
  # set of variables.  This determines what order variables need to be
  # calculated in, and creates necessary objects for numerical integration
  # (such as an initial value vector and a derivative proc).
  #
  def calculate()
    return if @calculated

    # Add magic "t" variable, and its alias "time"
    @varset.add_variable_if_unset("t", TimeVariable.new("t"))
    @varset.add_variable_if_unset("time", "t")

    # Figure out variable types and sort into Hash by type
    vars_by_type = sort_vars_by_type

    # TODO:  calculate explicit formulas for variables where possible,
    # untangle circular dependencies of variables

    # Get all variables that DiffEQ vars depend on
    required_vars = {}
    vars_by_type[:DiffEQ].each do |var|
      var.diffeq_depends_on.each { |dvar| required_vars[dvar.name] = dvar }
    end

    # Get the simple variables and their dependencies, then sort
    # them topologically so all dependencies are satisfied.
    @simple_deps = required_vars.values & vars_by_type[:Simple]
    @simple_deps = depsort_variables(@simple_deps)

    @derived_deps = required_vars.values & vars_by_type[:Derived]
    @derived_deps = depsort_variables(@derived_deps)

    @diffeqs = vars_by_type[:DiffEQ]

    # Assign indices into DiffEQ vector
    idx = 0
    @diffeqs.each do |var|
      var.index = idx
      idx += 1
    end

    @deriv_proc = proc { |x, y|
      raise "Y isn't a vector!" unless y.kind_of?(Vector)
      raise "X isn't a Float!" unless x.kind_of?(Float)
      raise "Y has wrong length!" unless y.size == @diffeqs.size

      values = yvec_to_value_table(x, y)

      deriv_list = @diffeqs.collect do |var|
	deriv_name = Variable.derivative_of_name(var.name)
        deriv = @varset.variable_by_name(deriv_name)
        deriv.evaluate(x, values)
      end

      Vector.elements(deriv_list)
    }

    # Calculate initial vector of dependent values
    @yzero = Vector.elements(@diffeqs.collect do |var|
	val = var.get_known_at_approx(0.0)
        raise "No known value of #{var.name} at t=0!" unless val
        val
    end)

    datapoint(t1, yvec) if @use_plotter

    @calculated = true
  end

  # This function takes a Hash of variable names and values and
  # advances all variables from time t1 to t2.  This is the essence of
  # the integrator tie-in code.  The times are Float values.  Vector
  # yvec gives the DiffEQ values at time t1, and supercedes their
  # value in the table unless it's nil.  Values is a Hash, and is the
  # values of the variables at time t1.  It returns two values --
  # a new table of variable values, and a new yvec for the next
  # invocation of the function.
  #
  def advance(values, yvec, t1, t2)
    raise "Have to calculate first (or again)!" unless @calculated

    if (yvec.nil? or yvec.size == 0) and t1.abs < 0.0001
      yvec = @yzero
    end

    if (values.nil? or values.empty?) and not (yvec.nil? or yvec.size == 0)
      values = yvec_to_value_table(t1, yvec)
    elsif yvec.nil? or yvec.size == 0
      yvec = Vector.elements([nil] * @diffeqs.size)
      @diffeqs.each do |dvar|
	raise "No value in table for '#{dvar.name}'!" unless values[dvar.name]
	yvec[dvar.index] = values[dvar.name]
      end
    end

    # For now, just assume no more than 1000 samples
    @integrator.set_max_samples(1000) if @use_plotter

    newyvec = @integrator.adaptive_integrate(yvec, t1, t2, EPSILON,
					     H_START, H_MIN, @deriv_proc)
    newvalues = yvec_to_value_table(t2, newyvec)

    if @use_plotter
      xp, yp = @integrator.get_sample_arrays
      xp = xp[1..-1]
      yp = yp[1..-1]
      datapoints(xp, yp)

      # Clear samples
      @integrator.set_max_samples(0)
    end

    [newvalues, newyvec]
  end

end

# Utility class and function for topological sorting

# The standard Ruby topsort library requires a class to include
# the TSort module and then declare functions to sort by.  This
# serves that purpose.
#
class TSortable < Hash #:nodoc:
  include TSort

  alias tsort_each_node each_key
  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end
end

end  # module DiffEQ
