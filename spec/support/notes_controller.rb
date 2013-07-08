class NotesController < ApplicationController
  %w(index show new create edit update destroy).each do |m|
    define_method(m) { render text: m }
  end

  # force name on all anonymous subclasses under test below
  def self.controller_name
    'notes'
  end
end
