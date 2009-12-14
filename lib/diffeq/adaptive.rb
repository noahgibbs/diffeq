#
# Integrator library
# Copyright (C) 2007 Noah Gibbs
#
# This library is in the public domain, and may be redistributed in any
# way.
#

require "matrix"

# This is the top-level driver, with logging, used by the more complex
# integrators in "Numerical Methods in C", second edition.  Code is
# adapted from C, of course.
#
module AdaptiveIntegrator
  include Integrator

  MAXSTP = 10000
  TINY = 1.0e-30

  # Take a single adaptive step.  The adaptive integrator's driver
  # function will call this repeatedly.  The parameters are y (the
  # initial vector), dydx (the initial derivative), x (the time
  # value), h (the starting step value), eps (the allowable error
  # for the step), yscal (how to scale epsilon for each component
  # of y), and derivs (the derivative function).
  #
  def integrate_ad_step(y, dydx, x, h, eps, yscal, derivs)
    raise "Adaptive integrators must implement integrate_ad_step!"
  end

  # Take adaptive steps to get from x1 to x2.  This is the driver
  # function.  The parameters are ystart (the initial vector), x1
  # (the first time value), x2 (the target time value), eps (the
  # allowable level of error), h1 (the initial recommended time
  # step value), hmin (the smallest allowable time step value)
  # and derivs (the derivative function).
  #
  def adaptive_integrate(ystart, x1, x2, eps, h1, hmin, derivs)

    x = x1
    h1 = -h1 unless h1 >= 0
    x2 - x1 >= 0 ? h = h1 : h = -h1
    @nok = @nbad = @count = 0

    y = ystart
    xsav = x - @dxsav * 2.0 if @kmax > 0

    nstp = 1
    while nstp <= MAXSTP
      dydx = derivs.call(x, y)
      #yscal = y.abs + (dydx * h).abs + Vector( [TINY] * y.length)
      yscal = y.collect2(dydx) { |yi, dyi| yi.abs + (dyi * h).abs + TINY }

      if @kmax > 0 and @count < @kmax and (x-xsav).abs > @dxsav.abs
	@xp << x
	@yp << y
        @count += 1
        xsav = x
      end

      h = x2 - x if ((x + h - x2)*(x + h - x1) > 0.0)
      x, y, hdid, hnext = integrate_ad_step(y, dydx, x, h, eps,
					    yscal, derivs)
      if hdid == h
        @nok += 1
      else
        @nbad += 1
      end

      if (x-x2)*(x2-x1) >= 0.0
        if @kmax != 0
          @xp << x
          @yp << y
          @count += 1
        end
        return y
      end

      raise "Step size too small!" if hnext.abs <= hmin
      h = hnext

      nstp += 1
    end

    raise "Too many steps in integration!"
  end

end # module AdaptiveIntegrator
