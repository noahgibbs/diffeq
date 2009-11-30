#!/usr/bin/ruby -w

#
# Integrator library
# Copyright (C) 2007 Noah Gibbs
#
# This library is in the public domain, and may be redistributed in any
# way.
#

require "matrix"

# Cash-Karp embedded Runge-Kutta integration. This algorithm is taken
# from "Numerical Recipes in C", second edition, though the ruby
# translation is my own.  This is the fixed step-size version, which
# is then used by the adaptive version.
#
class Cash_Karp_RK4
  include Integrator

  A2 = 0.2
  A3 = 0.3
  A4 = 0.6
  A5 = 1.0
  A6 = 0.875
  B21 = 0.2
  B31 = 3.0/40.0
  B32 = 9.0/40.0
  B41 = 0.3
  B42 = -0.9
  B43 = 1.2
  B51 = -11.0/54.0
  B52 = 2.5
  B53 = -70.0/27.0
  B54 = 35.0/27.0
  B61 = 1631.0/55296.0
  B62 = 175.0/512.0
  B63 = 575.0/13824.0
  B64 = 44275.0/110592.0
  B65 = 253.0/4096.0
  C1 = 37.0/378.0
  C3 = 250.0/621.0
  C4 = 125.0/594.0
  C6 = 512.0/1771.0
  DC1 = C1-2825.0/27648.0
  DC3 = C3-18575.0/48384.0
  DC4 = C4-13525.0/55296.0
  DC5 = -277.00/14336.0
  DC6 = C6-0.25

  def initialize
    Integrator_initialize()
  end

  def integrate_fixed_step(y, dydx, x, h, derivs)
    raise "Bad type!" unless [y, dydx].all? { |var| var.kind_of?(Vector) }
    raise "Bad type!" unless [x, h].all? { |var| var.kind_of?(Float) }
    raise "Bad method!" unless derivs.kind_of?(Proc)

    ytemp = y + dydx * B21 * h
    ak2 = derivs.call(x + A2*h, ytemp)
    ytemp = y + (dydx * B31 + ak2 * B32) * h
    ak3 = derivs.call(x + A3*h, ytemp)
    ytemp = y + (dydx * B41 + ak2 * B42 + ak3 * B43) * h
    ak4 = derivs.call(x + A4*h, ytemp)
    ytemp = y + (dydx * B51 + ak2 * B52 + ak3 * B53 + ak4 * B54) * h
    ak5 = derivs.call(x + A5*h, ytemp)
    ytemp = y + (dydx * B61 + ak2 * B62 + ak3 * B63 + ak4 * B64 +
		 ak5 * B65) * h
    ak6 = derivs.call(x + A6*h, ytemp)
    yout = y + (dydx * C1 + ak3 * C3 + ak4 * C4 + ak6 * C6) * h
    yerr = (dydx * DC1 + ak3 * DC3 + ak4 * DC4 + ak5 * DC5 + ak6 * DC6) * h

    # Return new values and error terms
    [yout, yerr]
  end
end
