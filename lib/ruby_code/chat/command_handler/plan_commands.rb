# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # Slash commands for toggling plan mode and saving plans.
      module PlanCommands
        private

        def cmd_plan(rest)
          case rest&.strip&.downcase
          when "on"          then enable_plan_mode
          when "off"         then disable_plan_mode(force: false)
          when "off --force" then disable_plan_mode(force: true)
          when nil, ""       then show_plan_status
          else                    handle_plan_subcommand(rest.strip)
          end
        end

        def handle_plan_subcommand(rest)
          if rest.downcase.start_with?("save")
            filename = rest.sub(/\Asave\s*/i, "").strip
            save_plan(filename.empty? ? nil : filename)
          else
            @state.add_message(:system, "Usage: /plan [on|off|save [filename]]")
          end
        end

        def enable_plan_mode
          if @state.plan_mode_active?
            @state.add_message(:system, "Plan mode is already enabled.")
            return
          end

          deactivate_agent_if_needed
          @llm_bridge.toggle_plan_mode!(true)
          @state.activate_plan_mode!
          @state.add_message(:system,
                             "Plan mode enabled. Describe what you want to build and the model " \
                             "will help you create a structured plan.")
        end

        def deactivate_agent_if_needed
          return unless @llm_bridge.agentic_mode

          @llm_bridge.toggle_agentic_mode!(false)
          @state.add_message(:system, "Agent mode disabled.")
        end

        def disable_plan_mode(force:)
          unless @state.plan_mode_active?
            @state.add_message(:system, "Plan mode is already disabled.")
            return
          end

          return if unsaved_plan_warned?(force)

          @llm_bridge.toggle_plan_mode!(false)
          @state.deactivate_plan_mode!
          @state.add_message(:system, "Plan mode disabled. Switched back to chat mode.")
        end

        def unsaved_plan_warned?(force)
          return false if force || !@state.has_unsaved_plan?

          @state.add_message(:system,
                             "You have an unsaved plan. Use /plan save [filename] first, " \
                             "or /plan off --force to discard.")
          true
        end

        def show_plan_status
          if @state.plan_mode_active?
            saved_status = @state.has_unsaved_plan? ? " (unsaved changes)" : ""
            @state.add_message(:system, "Plan mode: enabled#{saved_status}. Use /plan off to disable.")
          else
            @state.add_message(:system, "Plan mode: disabled. Use /plan on to enable.")
          end
        end

        def save_plan(filename)
          plan_content = @state.current_plan

          unless plan_content
            @state.add_message(:system, "No plan to save. Generate a plan first.")
            return
          end

          filename ||= generate_plan_filename(plan_content)
          write_plan_file(filename, plan_content)
        end

        def write_plan_file(filename, content)
          path = File.join(@llm_bridge.project_root, filename)
          File.write(path, content)
          @state.mark_plan_saved!
          @state.add_message(:system, "Plan saved to #{filename}")
        rescue StandardError => e
          @state.add_message(:system, "Failed to save plan: #{e.message}")
        end

        def generate_plan_filename(content)
          date = Time.now.strftime("%Y-%m-%d")
          first_line = content.lines.first&.strip || "plan"
          slug = first_line.gsub(/[^a-zA-Z0-9\s]/, "").split.first(4).join("_").downcase
          slug = "plan" if slug.empty?
          "plan_#{date}_#{slug}.md"
        end
      end
    end
  end
end
