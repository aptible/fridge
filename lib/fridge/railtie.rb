# frozen_string_literal: true

require 'fridge/rails_helpers'

module Fridge
  # Railtie that automatically includes RailsHelpers into ActionController::Base.
  class Railtie < Rails::Railtie
    initializer 'fridge.rails_helpers' do
      ActionController::Base.include RailsHelpers
    end
  end
end
