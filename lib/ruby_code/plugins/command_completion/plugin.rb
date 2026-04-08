# frozen_string_literal: true

require_relative "state_extension"
require_relative "input_extension"
require_relative "renderer_extension"

module RubyCode
  module Plugins
    module CommandCompletion
      # Built-in plugin that shows a filtered list of slash-command
      # suggestions as the user types, with Tab to accept.
      class Plugin < Base
        def self.plugin_name = :command_completion

        def self.state_extension = StateExtension

        def self.input_extension = InputExtension

        def self.renderer_extension = RendererExtension

        def self.input_handler_method = :handle_command_completion_input

        def self.render_method = :render_command_completer
      end
    end
  end
end
