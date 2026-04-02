# frozen_string_literal: true

require "ruby_llm"

module RubyCode
  module Chat
    # Handles slash commands entered in the chat input.
    class CommandHandler
      COMMANDS = {
        "/help" => :cmd_help,
        "/exit" => :cmd_exit,
        "/quit" => :cmd_exit,
        "/clear" => :cmd_clear,
        "/model" => :cmd_model,
        "/history" => :cmd_history,
        "/tokens" => :cmd_tokens
      }.freeze

      def initialize(state, llm_bridge:, user_config: nil)
        @state = state
        @llm_bridge = llm_bridge
        @user_config = user_config
      end

      def handle(raw_input)
        stripped = raw_input.strip
        return if stripped.empty?

        command, rest = stripped.split(" ", 2)
        method_name = COMMANDS[command.downcase]

        if method_name
          send(method_name, rest)
        else
          @state.add_message(:system, "Unknown command: #{command}. Type /help for available commands.")
        end
      end

      private

      def cmd_help(_rest)
        help_text = <<~HELP
          Available commands:
            /help              Show this help message
            /model             Show the current model
            /model <name>      Switch to a different model
            /clear             Clear the conversation history
            /history           Show conversation summary
            /tokens            Show token usage for this session
            /exit, /quit       Exit the chat
        HELP

        @state.add_message(:system, help_text)
      end

      def cmd_exit(_rest)
        @state.should_quit = true
      end

      def cmd_clear(_rest)
        @state.clear_messages!
        @state.add_message(:system, "Conversation cleared.")
      end

      def cmd_model(rest)
        if rest.nil? || rest.strip.empty?
          @state.add_message(:system, "Current model: #{@state.model}")
          return
        end

        name = rest.strip
        models = fetch_chat_models

        if models.any?
          match = models.find { |m| model_id(m) == name }

          unless match
            suggestions = models.select { |m| model_id(m).include?(name) }.map { |m| model_id(m) }.first(5)
            msg = "Model '#{name}' not found."
            msg += " Did you mean: #{suggestions.join(', ')}?" if suggestions.any?
            @state.add_message(:system, msg)
            return
          end
        end

        @state.model = name
        @llm_bridge.reset_chat!(name)
        @user_config&.set_config("model", name)
        @state.add_message(:system, "Model switched to #{name}.")
      rescue StandardError => e
        @state.add_message(:system, "Failed to switch model: #{e.message}")
      end

      def cmd_history(_rest)
        snapshot = @state.messages_snapshot
        conv = snapshot.reject { |m| m[:role] == :system }

        if conv.empty?
          @state.add_message(:system, "No conversation history yet.")
          return
        end

        lines = conv.map.with_index(1) do |msg, i|
          role = msg[:role].to_s.capitalize
          preview = msg[:content].to_s.lines.first&.strip || ""
          preview = "#{preview[0..60]}..." if preview.length > 60
          "  #{i}. [#{role}] #{preview}"
        end

        @state.add_message(:system, "Conversation history (#{conv.size} messages):\n#{lines.join("\n")}")
      end

      def cmd_tokens(_rest)
        ti = @state.total_input_tokens
        to = @state.total_output_tokens
        @state.add_message(:system, "Token usage this session: #{ti} input, #{to} output (#{ti + to} total)")
      end

      def fetch_chat_models
        RubyLLM.models.chat_models.to_a
      rescue StandardError
        []
      end

      def model_id(model)
        return model.id if model.respond_to?(:id)

        model.to_s
      end
    end
  end
end
