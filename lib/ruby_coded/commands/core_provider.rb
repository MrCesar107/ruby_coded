# frozen_string_literal: true

require_relative "command_definition"

module RubyCoded
  module Commands
    # Provides built-in slash commands.
    class CoreProvider
      DEFINITIONS = [
        {
          name: "/help",
          description: "Show help message",
          handler: :cmd_help,
          source: :core,
          usage: "/help"
        },
        {
          name: "/exit",
          description: "Exit the chat",
          handler: :cmd_exit,
          source: :core,
          usage: "/exit"
        },
        {
          name: "/quit",
          description: "Exit the chat",
          handler: :cmd_exit,
          source: :core,
          usage: "/quit"
        },
        {
          name: "/clear",
          description: "Clear conversation history",
          handler: :cmd_clear,
          source: :core,
          usage: "/clear"
        },
        {
          name: "/model",
          description: "Select a model from available providers",
          handler: :cmd_model,
          source: :core,
          usage: "/model [name|--all]"
        },
        {
          name: "/history",
          description: "Show conversation summary",
          handler: :cmd_history,
          source: :core,
          usage: "/history"
        },
        {
          name: "/tokens",
          description: "Show detailed token usage and cost",
          handler: :cmd_tokens,
          source: :core,
          usage: "/tokens"
        },
        {
          name: "/agent",
          description: "Toggle agent mode (on/off)",
          handler: :cmd_agent,
          source: :core,
          usage: "/agent [on|off]"
        },
        {
          name: "/plan",
          description: "Toggle plan mode (on/off/save)",
          handler: :cmd_plan,
          source: :core,
          usage: "/plan [on|off|save [file]]"
        },
        {
          name: "/login",
          description: "Authenticate with an AI provider",
          handler: :cmd_login,
          source: :core,
          usage: "/login [provider]"
        },
        {
          name: "/commands",
          description: "Manage custom markdown commands",
          handler: :cmd_commands,
          source: :core,
          usage: "/commands [reload|list]"
        },
        {
          name: "/skills",
          description: "Manage project-local skills",
          handler: :cmd_skills,
          source: :core,
          usage: "/skills [reload|list]"
        }
      ].freeze

      def definitions
        DEFINITIONS.map { |attrs| CommandDefinition.new(**attrs) }
      end
    end
  end
end
