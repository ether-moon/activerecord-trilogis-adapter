# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "activerecord-trilogis-adapter"
  spec.summary = "ActiveRecord adapter for MySQL with spatial extensions, built on Trilogy."
  spec.description =
    "ActiveRecord connection adapter for MySQL. It extends the Rails built-in Trilogy adapter " \
    "and adds spatial extensions support via RGeo. Compatible with Rails 8.0+ native Trilogy adapter. " \
    "Requires Ruby 3.2+ and Rails 8.0+."

  spec.version = "8.0.0"
  spec.author = "Ether Moon"
  spec.email = "chipseru@gmail.com"
  spec.homepage = "http://github.com/ether-moon/activerecord-trilogis-adapter"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*", "LICENSE.txt"]
  spec.platform = Gem::Platform::RUBY

  spec.required_ruby_version = ">= 3.2.0", "< 3.5"

  spec.add_dependency "activerecord", ">= 8.0", "< 9.0"
  spec.add_dependency "rgeo", "~> 3.0"
  spec.add_dependency "rgeo-activerecord", "~> 7.0"

  spec.add_development_dependency "minitest", "~> 5.4"
  spec.add_development_dependency "mocha", "~> 2.0"
  spec.add_development_dependency "ostruct"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "trilogy", "~> 2.7"
  spec.metadata["rubygems_mfa_required"] = "true"
end
