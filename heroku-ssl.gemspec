$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "heroku_ssl/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "heroku-ssl"
  s.version     = HerokuSSL::VERSION
  s.authors     = ["Kai Marshland"]
  s.email       = ["kaimarshland@gmail.com"]
  s.homepage    = 'https://github.com/KMarshland/heroku-ssl'
  s.summary     = "Quickly and easily add SSL to a Rails App with Let's Encrypt"
  s.description = 'Designed for Heroku, but can be adapted for other hosts as well'
  s.license     = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.0.0", ">= 4.2.0"
  s.add_dependency "acme-client", "~> 0.4.0"
end
