require File.dirname(__FILE__) + '/test_helper.rb'

class TestIntegrator < Test::Unit::TestCase

  def setup
    # Test both fixed-step and adaptive integrators
    @fixed_integrator = Cash_Karp_RK4.new()
    @ad_integrator = Adaptive_Cash_Karp_RK45.new()
  end

  def assert_within_epsilon(actual, expected)
    if expected.kind_of?(Vector)
      expected.collect2(actual) { |x, y|
	assert_within_epsilon(x, y)
      }
    else
      (actual - expected).abs / expected < 0.001 or
	raise "Values don't match!  Actual was #{actual}, not #{expected}!"
    end
  end

  def test_a_w_e
    assert_within_epsilon(10000.0, 10000.00001)
    assert_within_epsilon(10000.0, 10001)
  end

  def test_const_func
    const_deriv_proc = proc do |x, y|
      y.collect { |yi| 0.1 }
    end
    constvec = Vector.elements([1.0] * 100)
    constderiv = const_deriv_proc.call(0, constvec)

    @fixed_integrator.set_max_samples(100, 0.01)
    # Integrate a constant derivative over a distance of 1.0
    yout, yerr = @fixed_integrator.integrate_fixed_step(constvec, constderiv,
							0.0, 1.0,
							const_deriv_proc)
    assert_within_epsilon(yout, Vector.elements([ 1.1 ] * 100))
  end

  def test_exp_func
    # This takes the derivative of e^x for each vector element.
    # The derivative of e^x is just e^x again.
    exp_deriv_proc = proc do |x, y|
      y.collect { |yi| yi }
    end

    onevec = Vector.elements([1.0] * 100)
    expderiv = exp_deriv_proc.call(0, onevec)
    dist = 0.01 # Keep this small because we only make one integration step
    # Integrate e^x over a distance of 1.0, starting at e^0 == 1.0
    yout, yerr = @fixed_integrator.integrate_fixed_step(onevec, expderiv,
							0.0, dist,
							exp_deriv_proc)
    assert_within_epsilon(yout, Vector.elements([ Math::E ** dist ] * 100))

    y = @ad_integrator.adaptive_integrate(onevec, 0.0, 1.0, 0.001, 0.01,
					  0.0001, exp_deriv_proc)
    assert_within_epsilon(y, Vector.elements( [ Math::E ] * 100 ))
  end

end
