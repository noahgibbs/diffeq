require "diffeq"
require "ftools"      # for File.exist?

PLOTTERFILE = "volt.gnuplot"

varset = DiffEQVarSet.new
advancer = DiffEQAdvancer.new(varset)

File.delete(PLOTTERFILE) if File.exist?(PLOTTERFILE)

# http://en.wikipedia.org/wiki/Lotka-Volterra_equation
preyvar = varset.add_variable("x", "")
predvar = varset.add_variable("y", "")

# These are initial populations of predator and prey
preyvar.add_known(0.0, 30.0)
predvar.add_known(0.0, 4.0)

# Alpha is the prey growth rate when unmolested -- roughly how fast the prey
# reproduces.  High alpha means high fecundity.
alpha = 1.0

# Beta is the likelihood of predator and prey meeting - roughly how efficient
# the predator is at finding and eating prey.  High beta means the predator
# finds/kills prey easily.
beta = 0.2

# Delta is how frequently the predator reproduces, which can be different
# from the rate at which they eat prey.  High delta means more fecund.
delta = 0.3

# Gamma is the rate at which the predator dies off naturally.  High gamma
# means quicker exponential decay in the predator population.
gamma = 0.8

varset.add_variable("x_D1", "#{alpha} * x - #{beta} * x * y")
varset.add_variable("y_D1", "#{delta} * x * y - #{gamma} * y")

advancer.calculate

advancer.start_plotter

yzero = advancer.get_yzero_values
values, yvec = advancer.advance(values, yvec, 0.0, 100.0)

advancer.write_plotter_file(PLOTTERFILE)
advancer.stop_plotter
