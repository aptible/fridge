$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'active_support/all'
require 'action_controller'
require 'action_dispatch'
require 'action_view'

require 'fridge'
require 'fridge/rails_helpers'

require 'rspec'
require 'rspec/rails'

# Load shared spec files
Dir["#{File.dirname(__FILE__)}/shared/**/*.rb"].each do |file|
  require file
end

RSpec.configure do |config|
  config.before { Fridge.configuration.reset }
end
