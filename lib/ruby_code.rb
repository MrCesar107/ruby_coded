# frozen_string_literal: true

require_relative "ruby_code/version"
require_relative "ruby_code/initializer"
require "ruby_code/version"

begin
  raise "This gem requires Ruby 3.2.0 or higher" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
rescue LoadError
end

# Main module for the RubyCode gem
module RubyCode
  Initializer.new
end
