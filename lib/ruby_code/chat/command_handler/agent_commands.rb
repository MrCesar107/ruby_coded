# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # Slash commands for toggling agentic mode on/off.
      module AgentCommands
        private

        def cmd_agent(rest)
          arg = rest&.strip&.downcase

          case arg
          when "on"
            enable_agent_mode
          when "off"
            disable_agent_mode
          when nil, ""
            show_agent_status
          else
            @state.add_message(:system, "Usage: /agent [on|off]")
          end
        end

        def enable_agent_mode
          if @llm_bridge.agentic_mode
            @llm_bridge.reset_agent_session!
            @state.add_message(:system,
                               "Agent session reset. Tool call counters cleared — ready for a new task.")
            return
          end

          @llm_bridge.toggle_agentic_mode!(true)
          @state.add_message(:system,
                             "Agent mode enabled. The model can now use tools to interact with your project files.")
        end

        def disable_agent_mode
          unless @llm_bridge.agentic_mode
            @state.add_message(:system, "Agent mode is already disabled.")
            return
          end

          @llm_bridge.toggle_agentic_mode!(false)
          @state.add_message(:system, "Agent mode disabled. Switched back to chat-only mode.")
        end

        def show_agent_status
          status = @llm_bridge.agentic_mode ? "enabled" : "disabled"
          @state.add_message(:system, "Agent mode: #{status}. Use /agent on or /agent off to toggle.")
        end
      end
    end
  end
end
