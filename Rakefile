require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
require 'fileutils'
require './lib/diffeq'

Hoe.plugin :newgem

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec 'diffeq' do
  self.developer 'Noah Gibbs', 'noah_gibbs at yahoo dot youknowwhat'
  #self.post_install_message = 'PostInstall.txt' # remove if post-install message not required
  self.rubyforge_name       = self.name
  # self.extra_deps         = [['activesupport','>= 2.0.2']]

end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

# remove_task :default
# task :default => [:spec, :features]
