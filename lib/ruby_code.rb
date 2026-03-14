# frozen_string_literal: true

require_relative "ruby_code/version"
require_relative "ruby_code/initializer"

# Main module for the RubyCode gem
module RubyCode
  class Error < StandardError; end

  Initializer.new
end
