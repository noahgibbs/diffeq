#!/usr/bin/ruby -w

#
# Integrator library
# Copyright (C) 2007 Noah Gibbs
#
# This library is in the public domain, and may be redistributed in any
# way.
#

require "matrix"

# This is the adaptive Cash-Karp embedded Runge-Kutta integrator.  It
# inherits from the fixed-step version, and calculates the per-step
# error and decides how to scale the current timestep.  The algorithm
# here is taken from "Numerical Recipes in C", second edition.
#
class Adaptive_Cash_Karp_RK45 < Cash_Karp_RK4
  include Integrator
  include AdaptiveIntegrator

  SAFETY = 0.9
  PGROW = -0.2
  PSHRNK = -0.25
  ERRCON = 1.89e-4

  # This is the RK4/5 adaptive integration step function.  The
  # prototype is exactly like its parent class, and the algorithm
  # is specific to Cash-Karp embedded fourth-order Runge-Kutta.
  #
  def integrate_ad_step(y, dydx, x, htry, eps, yscal, derivs)
    h = htry

    while(true) do
      ytemp, yerr = integrate_fixed_step(y, dydx, x, h, derivs)
      errmax = yerr.collect2(yscal) { |err, scal| (err/scal).abs }.max
      errmax /= eps
      break if errmax <= 1.0
      htemp = SAFETY * h * (errmax ** PSHRNK)
      h = h >= 0.0 ? [htemp, 0.1 * h].max : [htemp, 0.1 * h].min
      xnew = x + h
      raise "Step underflow!" if xnew == x
    end

    if errmax > ERRCON
      hnext = SAFETY * h * (errmax ** PGROW)
    else
      hnext = 5 * h
    end

    hdid = h
    x += h
    y = ytemp

    [x, y, hdid, hnext]
  end

end
