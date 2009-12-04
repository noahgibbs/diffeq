require "matrix"

module DiffEQ::Plottable

  @plotter = nil

  def set_plotter(newbool)
    @plotter = newbool
    @plotter_array = []
    @plotter_array_x = []
    @plotter_vecarray = []
    @plotter_vecarray_x = []
    @plotter_last_x = nil
    @plotter_last_y = nil
  end

  def datapoint(x, y)
    return unless @plotter

    if x.is_a?(Array) || x.is_a?(Vector)
      # Vector has no .each() yet, so use collect instead
      (0..(x.size - 1)).collect do |idx|
	datapoint(x[idx], y[idx])
      end
      return
    end

    # Remove duplicates
    return if x == @plotter_last_x && y == @plotter_last_y

    @plotter_last_x = x
    @plotter_last_y = y

    if y.is_a?(Numeric)
      @plotter_array << y
      @plotter_array_x << x
    elsif y.is_a?(Vector)
      @plotter_vecarray << y
      @plotter_vecarray_x << x
    end
  end

  alias datapoints datapoint

  def plot_to_file(filename, options = {})
    default_options = { :points => true, :vectors => true }
    options = default_options.merge(options)
    File.open(filename, "w") do |f|
      px = @plotter_array_x
      py = @plotter_array
      vx = @plotter_vecarray_x
      vy = @plotter_vecarray

      out_array = []
      if options[:points]
        out_array += [[px, py]]
      end
      if options[:vectors]
        out_array += [[vx, vy]]
      end

      f.write(YAML::dump out_array)
    end
  end

end
