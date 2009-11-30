#!/usr/bin/ruby -w

#
# Integrator library
# Copyright (C) 2007-2009 Noah Gibbs
#

$:.unshift File.dirname(__FILE__)

module Integrator

  # Initialize the logging and other setup for the Integrator module.
  # New integrators should call this from initialize().
  #
  def Integrator_initialize()
    @kmax = 0     # Max steps to save
    @dxsav = 0.01 # Minimum step size to save data
    @xp = nil      # Array to save X coords
    @yp = nil      # Array to save Y vectors

    # Stats from most recent integrate call
    @nok = 0
    @nbad = 0
    @count = 0
  end

  protected

  public

  # Set sample logging.  Num_max is the maximum number of
  # samples to log, and min_x_save is the minimum distance
  # between x samples to bother to log.  To unset logging,
  # call this function with num_max == 0.
  #
  def set_max_samples(num_max, min_x_save = 0.01)
    @kmax = num_max
    @count = @nok = @nbad = 0
    @xp = []
    @yp = []
    @dxsav = min_x_save
  end

  # Get samples that were logged.  This function returns a list
  # of two values, the x (time) coordinates, and the y (dependent)
  # Vector.
  #
  def get_sample_arrays
    [@xp, @yp]
  end

  # On the last sampled run, return a list of two numbers - the
  # number of successful forward steps, followed by the number
  # of cancelled forward steps.  Adaptive stepping means that
  # sometimes the error is too high and the integrator will
  # go back and try a smaller step.
  #
  def get_good_and_bad_sample_count
    [@nok, @nbad]
  end

  # Integrate from time t_start to t_end, starting from initial
  # value y0.  Use the 'derivs' proc to evaluate derivatives at
  # a given point.  Start by taking a step of size step_start,
  # take steps no smaller than step_min, and attempt to keep the
  # error per step down to a maximum of epsilon.
  #
  def integrate(y0, t_start, t_end, derivs, step_start = 0.1,
                step_min = 0.0001, epsilon = 0.01)
    raise "y0 must be a vector!" unless y0.kind_of?(Vector)
    raise "Must give derivative proc!" unless derivs.kind_of?(Proc)

    adaptive_integrate(y0, t_start, t_end, epsilon,
                       step_start, step_min, derivs)
  end

end
