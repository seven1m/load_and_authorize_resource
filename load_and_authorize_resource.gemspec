Gem::Specification.new do |s|
  s.name         = "load_and_authorize_resource"
  s.version      = "0.4.1"
  s.author       = "Tim Morgan"
  s.email        = "tim@timmorgan.org"
  s.homepage     = "https://github.com/seven1m/load_and_authorize_resource"
  s.summary      = "Auto-loads and authorizes resources in your controllers in Rails 4 and up."
  s.files        = %w(README.md) + Dir['lib/**/*'].to_a
  s.require_path = "lib"
  s.license      = "MIT"
  s.has_rdoc     = "yard"
  s.add_dependency "rails", ">= 4.0"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "yard"
  s.add_development_dependency "redcarpet"
end
