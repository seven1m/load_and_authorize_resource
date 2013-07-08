require_relative '../../lib/load_and_authorize_resource'

class ApplicationController < ActionController::Base
  include LoadAndAuthorizeResource
end

