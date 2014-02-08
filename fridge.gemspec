# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'English'
require 'fridge/version'

Gem::Specification.new do |spec|
  spec.name          = 'fridge'
  spec.version       = Fridge::VERSION
  spec.authors       = ['Frank Macreery']
  spec.email         = ['frank@macreery.com']
  spec.description   = %q{Token validation for distributed resource servers}
  spec.summary       = %q{Token validation for distributed resource servers}
  spec.homepage      = 'https://github.com/aptible/fridge'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.test_files    = spec.files.grep(/^spec\//)
  spec.require_paths = ['lib']

  spec.add_dependency 'gem_config'
  spec.add_dependency 'jwt'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'aptible-tasks'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rspec', '~> 2.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'pry'
end
