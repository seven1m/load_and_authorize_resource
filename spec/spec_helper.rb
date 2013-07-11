ENV["RAILS_ENV"] = "test"

require 'rails/all'
require 'rspec/rails'

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = true
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

Dir[File.expand_path('../support/**/*.rb', __FILE__)].sort.each { |f| require f }

class FakeApplication < Rails::Application; end

Rails.application = FakeApplication

class ActionController::Base
  include FakeApplication.routes.url_helpers
end
