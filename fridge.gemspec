# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'English'
require 'fridge/version'

Gem::Specification.new do |spec|
  spec.name          = 'fridge'
  spec.version       = Fridge::VERSION
  spec.authors       = ['Frank Macreery']
  spec.email         = ['frank@macreery.com']
  spec.description   = 'Token validation for distributed resource servers'
  spec.summary       = 'Token validation for distributed resource servers'
  spec.homepage      = 'https://github.com/aptible/fridge'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'gem_config'
  spec.add_dependency 'jwt', '~> 2.3.0'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-capybara'
  spec.add_development_dependency 'rubocop-factory_bot'
  spec.add_development_dependency 'rubocop-rails'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'rubocop-rspec_rails'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
