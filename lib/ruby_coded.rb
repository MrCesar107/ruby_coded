# frozen_string_literal: true

require_relative "ruby_coded/version"
require_relative "ruby_coded/config/user_config"
require_relative "ruby_coded/auth/auth_manager"
require_relative "ruby_coded/initializer"
require_relative "ruby_coded/plugins"
require_relative "ruby_coded/commands"
require_relative "ruby_coded/skills"

raise "This gem requires Ruby 3.3.0 or higher" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.3.0")

# Main module for the RubyCoded gem
module RubyCoded
  def self.start
    Initializer.new
  end
end
