# frozen_string_literal: true

require_relative "ruby_code/version"
require_relative "ruby_code/config/user_config"
require_relative "ruby_code/auth/auth_manager"
require_relative "ruby_code/initializer"

begin
  raise "This gem requires Ruby 3.2.0 or higher" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
rescue LoadError
end

# Main module for the RubyCode gem
module RubyCode
  def self.start
    Initializer.new
  end
end
