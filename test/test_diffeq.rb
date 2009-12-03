require File.dirname(__FILE__) + '/test_helper.rb'

class TestDiffeq < Test::Unit::TestCase

  PLOTTERFILE = "graphout.gnuplot"
  PLOTTERFILE2 = "graphout_2.gnuplot"

  def setup
    File.delete(PLOTTERFILE) if File.exist?(PLOTTERFILE)
    File.delete(PLOTTERFILE2) if File.exist?(PLOTTERFILE2)

    @varset = DiffEQ::VarSet.new
    @advancer = DiffEQ::Advancer.new(@varset)
  end

  def test_basic_vars
    var_empty = @varset.add_variable("emptyvar", nil)
    assert(var_empty.variable_type == :NoInfo, "Empty should be unknown!")

    var_0 = @varset.add_variable("zerovar", "0")
    assert(var_0.constant?, "Zero isn't constant!")

    var_x = @varset.add_variable("x", "37 * 45.96 + 7e-7 / 9e5")
    assert(var_x.constant?, "arithmetic on numbers isn't constant!")

    var_z = @varset.add_variable("z", "37 * 45.96 + x - 7e-7 / 9e5")
    assert(var_z.variable_type == :Simple,
	   "arithmetic on constants isn't constant!")

    var_yd1 = @varset.add_variable("y_D1", "0.1")
    assert(var_yd1.constant?, "Float isn't constant!")
  end

  def test_diffeq_vars
    # Prereqs, already tested above
    var_x = @varset.add_variable("x", "37 * 45.96 + 7e-7 / 9e5")
    var_yd1 = @varset.add_variable("y_D1", "0.1")

    var_y = @varset.add_variable("y", nil)
    var_y.add_known(0, 50)
    assert(var_y.variable_type == :DiffEQ)

    var_xy = @varset.add_variable("xyvar", "x * y")
    assert(var_xy.variable_type == :Derived)

    var_y25 = @varset.add_variable("y25var", "y * 0.025")
    assert(var_y25.variable_type == :Derived)
  end

  def test_deriv_name
    assert(DiffEQ::Variable.derivative_of_name("var") == "var_D1")
    assert(DiffEQ::Variable.derivative_of_name("blah_D3") == "blah_D4")
  end

  def test_integration
    # Create a variable x such that x(0.0) = 1.0,
    # and dx/dt equals x(t) for all t values.
    # So x(t) should equal e^t.
    testvar = @varset.add_variable("x", "")
    testvar.add_known(0.0, 1.0)
    testvar = @varset.add_variable("x_D1", "x")

    @advancer.calculate

    yzero = @advancer.get_yzero_values
    values, yvec = @advancer.advance(nil, yzero, 0.0, 4.0)
    assert(yvec.size == 1)

    assert_in_delta(yvec[0], Math::E ** 4.0, 0.5)
  end

  def test_plotter
    # Create a variable x such that x(0.0) = 0.0,
    # and dx/dt equals 1.0 for all t values.
    # So x(t) should equal t.
    testvar = @varset.add_variable("x", "")
    testvar.add_known(0.0, 0.0)
    testvar = @varset.add_variable("x_D1", "1.0")

    @advancer.calculate

    @advancer.start_plotter

    yzero = @advancer.get_yzero_values
    values, yvec = @advancer.advance(nil, yzero, 0.0, 4.0)
    assert(yvec.size == 1)

    assert_in_delta(yvec[0], 4.0, 0.1)

    @advancer.write_plotter_file(PLOTTERFILE)
    @advancer.stop_plotter

    assert(File.exist?(PLOTTERFILE))
  end

  def test_plotter_2
    testvar = @varset.add_variable("x", "")
    testvar.add_known(0.0, 0.0)
    testvar = @varset.add_variable("x_D1", "2 * sin(t) + x + 0.05")

    @advancer.calculate

    @advancer.start_plotter

    yzero = @advancer.get_yzero_values
    yvec = yzero
    values = nil
    time = 0.0
    (0..120).each do |step|
      values, yvec = @advancer.advance(values, yvec, time, time + 0.1)
      time += 0.1
    end
    assert(yvec.size == 1)

    @advancer.write_plotter_file(PLOTTERFILE2)
    @advancer.stop_plotter

    assert(File.exist?(PLOTTERFILE2))
  end

end
