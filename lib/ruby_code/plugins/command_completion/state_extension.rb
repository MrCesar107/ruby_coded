# frozen_string_literal: true

module RubyCode
  module Plugins
    module CommandCompletion
      # Mixed into Chat::State to add command-completion tracking.
      module StateExtension
        COMMAND_INFO = {
          "/help" => "Show help message",
          "/model" => "Select or switch model",
          "/clear" => "Clear conversation history",
          "/history" => "Show conversation summary",
          "/tokens" => "Show token usage",
          "/agent" => "Toggle agent mode (on/off)",
          "/plan" => "Toggle plan mode (on/off/save)",
          "/exit" => "Exit the chat",
          "/quit" => "Exit the chat"
        }.freeze

        def self.included(base)
          base.attr_reader :command_completion_index
        end

        def init_command_completion
          @command_completion_index = 0
        end

        def command_completion_active?
          buf = @input_buffer
          buf.start_with?("/") && !buf.include?(" ") && !command_suggestions.empty?
        end

        # Returns an array of [command, description] pairs matching the
        # current input buffer prefix.
        def command_suggestions
          prefix = @input_buffer.downcase
          all_descriptions = merged_command_descriptions
          all_descriptions.select { |cmd, _| cmd.start_with?(prefix) }
                          .sort_by { |cmd, _| cmd }
        end

        def current_command_suggestion
          suggestions = command_suggestions
          return nil if suggestions.empty?

          idx = @command_completion_index % suggestions.size
          suggestions[idx]
        end

        def command_completion_up
          suggestions = command_suggestions
          return if suggestions.empty?

          @command_completion_index = (@command_completion_index - 1) % suggestions.size
        end

        def command_completion_down
          suggestions = command_suggestions
          return if suggestions.empty?

          @command_completion_index = (@command_completion_index + 1) % suggestions.size
        end

        def accept_command_completion!
          suggestion = current_command_suggestion
          return unless suggestion

          cmd, = suggestion
          @input_buffer.clear
          @input_buffer << cmd
          @cursor_position = @input_buffer.length
          @command_completion_index = 0
        end

        # Reset index when the buffer changes so selection stays coherent.
        def reset_command_completion_index
          @command_completion_index = 0
        end

        private

        def merged_command_descriptions
          base = COMMAND_INFO.dup
          base.merge!(RubyCode.plugin_registry.all_command_descriptions) if RubyCode.respond_to?(:plugin_registry)
          base
        end
      end
    end
  end
end
