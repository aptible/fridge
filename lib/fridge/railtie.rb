require 'fridge/rails_helpers'

module Fridge
  class Railtie < Rails::Railtie
    initializer 'fridge.rails_helpers' do
      ActionController::Base.send :include, RailsHelpers
    end
  end
end
