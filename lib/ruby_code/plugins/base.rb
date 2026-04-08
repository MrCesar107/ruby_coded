# frozen_string_literal: true

module RubyCode
  module Plugins
    # Abstract base class for all plugins. Subclass this and override
    # the class methods to declare what your plugin contributes.
    class Base
      class << self
        # Unique identifier for the plugin (Symbol).
        def plugin_name
          raise NotImplementedError, "#{name} must implement .plugin_name"
        end

        # Module to include in Chat::State (or nil).
        def state_extension = nil

        # Module to include in Chat::InputHandler (or nil).
        def input_extension = nil

        # Module to include in Chat::Renderer (or nil).
        def renderer_extension = nil

        # Module to include in Chat::CommandHandler (or nil).
        def command_handler_extension = nil

        # Symbol — method name defined by input_extension that processes
        # keyboard events. Signature: method(event) -> action_symbol | nil
        def input_handler_method = nil

        # Symbol — method name defined by renderer_extension that draws
        # the plugin overlay. Signature: method(frame, chat_area, input_area)
        def render_method = nil

        # Hash mapping command strings to method symbols,
        # e.g. { "/deploy" => :cmd_deploy }
        def commands = {}

        # Hash mapping command strings to human-readable descriptions,
        # e.g. { "/deploy" => "Deploy the application" }
        def command_descriptions = {}
      end
    end
  end
end
