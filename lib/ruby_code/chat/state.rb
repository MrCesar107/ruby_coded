# frozen_string_literal: true

require_relative "state/model_selection"
require_relative "state/messages"
require_relative "state/scrollable"

module RubyCode
  module Chat
    # This class is used to manage the state of the chat
    class State
      include ModelSelection
      include Messages
      include Scrollable

      attr_reader :input_buffer, :messages, :scroll_offset,
                  :mode, :model_list, :model_select_index, :model_select_filter
      attr_accessor :model, :streaming, :should_quit

      def initialize(model:)
        @model = model
        # String.new: literals like "" are frozen under frozen_string_literal
        @input_buffer = String.new
        @messages = []
        @streaming = false
        @should_quit = false
        @mutex = Mutex.new
        @scroll_offset = 0
        @mode = :chat
        @model_list = []
        @model_select_index = 0
        @model_select_filter = String.new
        @model_select_show_all = false
        init_plugin_state
      end

      def streaming?
        @streaming
      end

      def should_quit?
        @should_quit
      end

      def append_to_input(text)
        @input_buffer << text
        reset_command_completion_index if respond_to?(:reset_command_completion_index, true)
      end

      def delete_last_char
        @input_buffer.chop!
        reset_command_completion_index if respond_to?(:reset_command_completion_index, true)
      end

      def clear_input!
        @input_buffer.clear
      end

      def consume_input!
        input = @input_buffer.dup
        @input_buffer.clear
        input
      end

      private

      # Calls plugin state initializers (e.g. init_command_completion).
      def init_plugin_state
        return unless RubyCode.respond_to?(:plugin_registry)

        RubyCode.plugin_registry.plugins.each do |plugin|
          ext = plugin.state_extension
          next unless ext

          init_method = :"init_#{plugin.plugin_name}"
          send(init_method) if respond_to?(init_method, true)
        end
      end
    end
  end
end
