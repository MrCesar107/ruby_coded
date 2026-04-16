# frozen_string_literal: true

require "ruby_llm"

require_relative "command_handler/model_commands"
require_relative "command_handler/history_commands"
require_relative "command_handler/token_formatting"
require_relative "command_handler/token_commands"
require_relative "command_handler/agent_commands"
require_relative "command_handler/plan_commands"
require_relative "command_handler/login_commands"

module RubyCoded
  module Chat
    # Handles slash commands entered in the chat input.
    # Base commands are always available; plugins can contribute
    # additional commands via the plugin registry.
    class CommandHandler
      include ModelCommands
      include HistoryCommands
      include TokenFormatting
      include TokenCommands
      include AgentCommands
      include PlanCommands
      include LoginCommands

      BASE_COMMANDS = {
        "/help" => :cmd_help,
        "/exit" => :cmd_exit,
        "/quit" => :cmd_exit,
        "/clear" => :cmd_clear,
        "/model" => :cmd_model,
        "/history" => :cmd_history,
        "/tokens" => :cmd_tokens,
        "/agent" => :cmd_agent,
        "/plan" => :cmd_plan,
        "/login" => :cmd_login
      }.freeze

      HELP_TEXT = File.read(File.join(__dir__, "help.txt")).freeze

      def initialize(state, llm_bridge:, user_config: nil, credentials_store: nil, auth_manager: nil)
        @state = state
        @llm_bridge = llm_bridge
        @user_config = user_config
        @credentials_store = credentials_store
        @auth_manager = auth_manager
        @commands = build_command_map
      end

      def handle(raw_input)
        stripped = raw_input.strip
        return if stripped.empty?

        command, rest = stripped.split(" ", 2)
        method_name = @commands[command.downcase]

        if method_name
          send(method_name, rest)
        else
          @state.add_message(:system, "Unknown command: #{command}. Type /help for available commands.")
        end
      end

      private

      def build_command_map
        cmds = BASE_COMMANDS.dup
        cmds.merge!(RubyCoded.plugin_registry.all_commands)
        cmds
      end

      def cmd_help(_rest)
        text = HELP_TEXT.dup
        plugin_descs = RubyCoded.plugin_registry.all_command_descriptions
        unless plugin_descs.empty?
          text += "\nPlugin commands:\n"
          plugin_descs.each { |cmd, desc| text += "  #{cmd.ljust(18)} #{desc}\n" }
        end
        @state.add_message(:system, text)
      end

      def cmd_exit(_rest)
        @state.should_quit = true
      end

      def cmd_clear(_rest)
        @state.clear_messages!
        @state.add_message(:system, "Conversation cleared.")
      end
    end
  end
end
