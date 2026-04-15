# frozen_string_literal: true

require_relative "state/model_selection"
require_relative "state/messages"
require_relative "state/message_assistant"
require_relative "state/message_token_tracking"
require_relative "state/scrollable"
require_relative "state/tool_confirmation"
require_relative "state/plan_tracking"
require_relative "state/token_cost"

module RubyCode
  module Chat
    # This class is used to manage the state of the chat
    class State
      include ModelSelection
      include Messages
      include MessageAssistant
      include MessageTokenTracking
      include Scrollable
      include ToolConfirmation
      include PlanTracking
      include TokenCost

      attr_reader :input_buffer, :cursor_position, :input_scroll_offset, :messages, :scroll_offset,
                  :mode, :model_list, :model_select_index, :model_select_filter,
                  :streaming, :mutex
      attr_accessor :model, :should_quit

      MIN_RENDER_INTERVAL = 0.05

      def initialize(model:)
        @model = model
        # String.new: literals like "" are frozen under frozen_string_literal
        @input_buffer = String.new
        @cursor_position = 0
        @input_scroll_offset = 0
        @messages = []
        @streaming = false
        @should_quit = false
        @mutex = Mutex.new
        @dirty = true
        @last_render_at = 0.0
        @scroll_offset = 0
        @total_lines = 0
        @visible_height = 0
        @mode = :chat
        @model_list = []
        @model_select_index = 0
        @model_select_filter = String.new
        @model_select_show_all = false
        init_messages
        init_tool_confirmation
        init_plan_tracking
        init_token_cost
        init_plugin_state
      end

      def streaming=(value)
        @streaming = value
        mark_dirty!
      end

      def streaming?
        @streaming
      end

      def should_quit?
        @should_quit
      end

      def dirty?
        @mutex.synchronize do
          return false unless @dirty
          return true unless @streaming

          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          (now - @last_render_at) >= MIN_RENDER_INTERVAL
        end
      end

      def mark_clean!
        @mutex.synchronize do
          @dirty = false
          @last_render_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      def mark_dirty!
        @mutex.synchronize { @dirty = true }
      end

      # Updates the horizontal scroll offset of the input area so the
      # cursor is always visible.  Call this after every cursor / buffer
      # change.  +visible_width+ is set by the renderer each frame via
      # +update_input_visible_width+.
      def update_input_scroll_offset
        visible = @input_visible_width || 0
        return if visible <= 0

        if @cursor_position < @input_scroll_offset
          @input_scroll_offset = @cursor_position
        elsif @cursor_position >= @input_scroll_offset + visible
          @input_scroll_offset = @cursor_position - visible + 1
        end
      end

      # Called by the renderer so the state knows how many characters
      # fit on screen (inner width minus the prompt prefix).
      def update_input_visible_width(width)
        @input_visible_width = width
      end

      def append_to_input(text)
        @input_buffer.insert(@cursor_position, text)
        @cursor_position += text.length
        update_input_scroll_offset
        mark_dirty!
        reset_command_completion_index if respond_to?(:reset_command_completion_index, true)
      end

      def delete_last_char
        return if @cursor_position <= 0

        @input_buffer.slice!(@cursor_position - 1)
        @cursor_position -= 1
        update_input_scroll_offset
        mark_dirty!
        reset_command_completion_index if respond_to?(:reset_command_completion_index, true)
      end

      def move_cursor_left
        return if @cursor_position <= 0

        @cursor_position -= 1
        update_input_scroll_offset
        mark_dirty!
      end

      def move_cursor_right
        return if @cursor_position >= @input_buffer.length

        @cursor_position += 1
        update_input_scroll_offset
        mark_dirty!
      end

      def move_cursor_to_start
        return if @cursor_position == 0

        @cursor_position = 0
        update_input_scroll_offset
        mark_dirty!
      end

      def move_cursor_to_end
        return if @cursor_position == @input_buffer.length

        @cursor_position = @input_buffer.length
        update_input_scroll_offset
        mark_dirty!
      end

      def clear_input!
        @input_buffer.clear
        @cursor_position = 0
        @input_scroll_offset = 0
        mark_dirty!
      end

      def consume_input!
        input = @input_buffer.dup
        @input_buffer.clear
        @cursor_position = 0
        @input_scroll_offset = 0
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
