require 'gem_config'

require 'fridge/version'
require 'fridge/access_token'
require 'fridge/serialization_error'
require 'fridge/invalid_token'

require 'fridge/railtie' if defined?(Rails)

module Fridge
  include GemConfig::Base

  with_configuration do
    has :private_key, classes: [String]
    has :public_key, classes: [String]

    has :signing_algorithm, values: %w(RS512 RS256), default: 'RS512'

    # A validator must raise an exception or return a false value for an
    # invalid token
    has :validator, classes: [Proc], default: ->(token) { token.valid? }

    has :cookie_name, classes: [String, Symbol], default: :fridge_session
    has :cookie_options, classes: [Hash], default: {}
  end
end
