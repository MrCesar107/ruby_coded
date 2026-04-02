# frozen_string_literal: true

require "ratatui_ruby"

require_relative "state"
require_relative "input_handler"
require_relative "renderer"
require_relative "command_handler"
require_relative "llm_bridge"

module RubyCode
  module Chat
    # Main class for the AI chat
    class App
      def initialize(model:, user_config: nil)
        @model = model
        @user_config = user_config
        @state = State.new(model: model)
        @llm_bridge = LLMBridge.new(@state)
        @input_handler = InputHandler.new(@state)
        @command_handler = CommandHandler.new(@state, llm_bridge: @llm_bridge, user_config: @user_config)
      end

      def run
        RatatuiRuby.run do |tui|
          @tui = tui
          @renderer = Renderer.new(tui, @state)

          loop do
            @renderer.draw
            break if handle_event == :quit
          end
        end
      end

      private

      def handle_event
        event = @tui.poll_event
        action = @input_handler.process(event)
        case action
        when :quit
          :quit
        when :submit
          input = @state.consume_input!
          if input.start_with?("/")
            @command_handler.handle(input)
            return :quit if @state.should_quit?
          else
            @state.add_message(:user, input)
            @llm_bridge.send_async(input)
          end
        when :cancel_streaming
          @llm_bridge.cancel!
        when :scroll_up
          @state.scroll_up
        when :scroll_down
          @state.scroll_down
        when :scroll_top
          @state.scroll_to_top
        when :scroll_bottom
          @state.scroll_to_bottom
        end
      end
    end
  end
end
