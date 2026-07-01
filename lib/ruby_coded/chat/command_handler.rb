# frozen_string_literal: true

require "ruby_llm"

require_relative "command_handler/model_commands"
require_relative "command_handler/history_commands"
require_relative "command_handler/token_formatting"
require_relative "command_handler/token_commands"
require_relative "command_handler/agent_commands"
require_relative "command_handler/plan_commands"
require_relative "command_handler/login_commands"
require_relative "command_handler/custom_commands"
require_relative "command_handler/skill_commands"

module RubyCoded
  module Chat
    # Handles slash commands entered in the chat input.
    # Commands are resolved from a unified command catalog, which may
    # include core commands, plugin commands, and markdown commands.
    class CommandHandler
      include ModelCommands
      include HistoryCommands
      include TokenFormatting
      include TokenCommands
      include AgentCommands
      include PlanCommands
      include LoginCommands
      include CustomCommands
      include SkillCommands

      HELP_TEXT = File.read(File.join(__dir__, "help.txt")).freeze

      def initialize(state, llm_bridge:, command_catalog: nil, **deps)
        @state = state
        @llm_bridge = llm_bridge
        @user_config = deps[:user_config]
        @credentials_store = deps[:credentials_store]
        @auth_manager = deps[:auth_manager]
        @command_catalog = command_catalog
        @skill_catalog = deps[:skill_catalog]
        @commands = build_command_map
      end

      def handle(raw_input)
        stripped = raw_input.strip
        return if stripped.empty?

        command, rest = stripped.split(" ", 2)
        dispatch_command(command, rest)
      end

      private

      def dispatch_command(command, rest)
        normalized = command.downcase
        method_name = @commands[normalized]
        return send(method_name, rest) if method_name

        dispatch_dynamic_command(command, normalized, rest)
      end

      def dispatch_dynamic_command(command, normalized, rest)
        definition = @command_catalog&.find(normalized)
        return handle_markdown_command(definition, rest) if definition&.markdown?

        @state.add_message(:system, "Unknown command: #{command}. Type /help for available commands.")
      end

      def build_command_map
        return {} unless @command_catalog

        @command_catalog.command_map
      end

      def cmd_help(_rest)
        lines = ["Available commands:"]
        lines.concat(command_help_lines)
        append_static_help(lines)
        @state.add_message(:system, lines.join("\n"))
      end

      def command_help_lines
        @command_catalog.all_definitions.map { |definition| formatted_command_line(definition) }
      end

      def append_static_help(lines)
        static_help = HELP_TEXT.strip
        return if static_help.empty?

        lines << ""
        lines << static_help
      end

      def cmd_exit(_rest)
        @state.should_quit = true
      end

      def cmd_clear(_rest)
        @state.clear_messages!
        @state.add_message(:system, "Conversation cleared.")
      end

      def handle_markdown_command(definition, rest)
        prompt = build_markdown_prompt(definition, rest)

        @state.add_message(:system, "Running custom command #{definition.name}...")
        @state.add_message(:user, prompt)
        @llm_bridge.send_async(prompt)
      end

      def build_markdown_prompt(definition, rest)
        extra = rest.to_s.strip
        return definition.content if extra.empty?

        <<~PROMPT
          #{definition.content}

          Additional user input:
          #{extra}
        PROMPT
      end
    end
  end
end
