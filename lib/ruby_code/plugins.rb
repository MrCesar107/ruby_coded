# frozen_string_literal: true

require_relative "plugins/base"
require_relative "plugins/registry"

module RubyCode # :nodoc:
  # Returns the global plugin registry.
  def self.plugin_registry
    @plugin_registry ||= Plugins::Registry.new
  end

  # Register a plugin class that extends the chat functionality.
  def self.register_plugin(plugin_class)
    plugin_registry.register(plugin_class)
  end
end

require_relative "plugins/command_completion/plugin"

# Register built-in plugins
RubyCode.register_plugin(RubyCode::Plugins::CommandCompletion::Plugin)
