# frozen_string_literal: true

module RubyCode
  module Chat
    class App
      # Routes TUI events to the appropriate handler methods.
      module EventDispatch
        private

        def dispatch_event(event)
          action = @input_handler.process(event)
          case action
          when :quit then :quit
          when :submit then handle_submit
          when :model_selected, :model_select_cancel then dispatch_model_action(action)
          when :cancel_streaming, :tool_approved, :tool_approved_all, :tool_rejected then dispatch_llm_action(action)
          when :plan_clarification_selected, :plan_clarification_custom, :plan_clarification_skip
            dispatch_plan_clarification(action)
          when :scroll_up, :scroll_down, :scroll_top, :scroll_bottom then handle_scroll(action)
          end
        end

        def handle_submit
          input = @state.consume_input!
          if input.start_with?("/")
            @command_handler.handle(input)
            :quit if @state.should_quit?
          else
            @state.add_message(:user, input)
            @llm_bridge.send_async(input)
          end
        end

        def dispatch_model_action(action)
          case action
          when :model_selected then apply_selected_model
          when :model_select_cancel then @state.exit_model_select!
          end
        end

        def dispatch_llm_action(action)
          case action
          when :cancel_streaming then @llm_bridge.cancel!
          when :tool_approved then @llm_bridge.approve_tool!
          when :tool_approved_all then @llm_bridge.approve_all_tools!
          when :tool_rejected then @llm_bridge.reject_tool!
          end
        end

        def dispatch_plan_clarification(action)
          case action
          when :plan_clarification_selected
            handle_plan_clarification_response(@state.selected_clarification_option)
          when :plan_clarification_custom
            handle_plan_clarification_response(@state.clarification_custom_input.dup)
          when :plan_clarification_skip
            @state.exit_plan_clarification!
          end
        end

        def handle_plan_clarification_response(response)
          @state.exit_plan_clarification!
          @state.add_message(:user, response)
          @llm_bridge.send_async(response)
        end

        def handle_scroll(action)
          case action
          when :scroll_up then @state.scroll_up
          when :scroll_down then @state.scroll_down
          when :scroll_top then @state.scroll_to_top
          when :scroll_bottom then @state.scroll_to_bottom
          end
        end
      end
    end
  end
end
