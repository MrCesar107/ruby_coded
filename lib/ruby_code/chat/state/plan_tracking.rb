# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # Manages plan mode state and the clarification UI flow.
      # Plan mode tracks the current plan in memory and exposes
      # a clarification overlay (similar to ModelSelection) when
      # the LLM needs user input before generating the plan.
      module PlanTracking
        attr_reader :clarification_question, :clarification_options,
                    :clarification_index, :clarification_custom_input,
                    :clarification_input_mode

        def init_plan_tracking
          @plan_mode_active = false
          @current_plan = nil
          @plan_saved = true
          reset_clarification_state
        end

        # --- Plan mode ---

        def plan_mode_active?
          @plan_mode_active
        end

        def activate_plan_mode!
          @plan_mode_active = true
        end

        def deactivate_plan_mode!
          @plan_mode_active = false
          @current_plan = nil
          @plan_saved = true
          reset_clarification_state
        end

        def update_current_plan!(content)
          @mutex.synchronize do
            @current_plan = content
            @plan_saved = false
          end
        end

        def current_plan
          @mutex.synchronize { @current_plan }
        end

        def plan_saved?
          @mutex.synchronize { @plan_saved }
        end

        def mark_plan_saved!
          @mutex.synchronize { @plan_saved = true }
        end

        def has_unsaved_plan?
          @mutex.synchronize { @current_plan && !@plan_saved }
        end

        def clear_plan!
          @mutex.synchronize do
            @current_plan = nil
            @plan_saved = true
          end
        end

        # --- Clarification UI (pattern: ModelSelection) ---

        def plan_clarification?
          @mode == :plan_clarification
        end

        def enter_plan_clarification!(question, options)
          @mutex.synchronize do
            @clarification_question = question
            @clarification_options = options
            @clarification_index = 0
            @clarification_custom_input = String.new
            @clarification_input_mode = :options
            @mode = :plan_clarification
          end
        end

        def exit_plan_clarification!
          @mutex.synchronize do
            @mode = :chat
            reset_clarification_state
          end
        end

        def clarification_up
          return if @clarification_options.empty?

          @clarification_index = (@clarification_index - 1) % @clarification_options.size
        end

        def clarification_down
          return if @clarification_options.empty?

          @clarification_index = (@clarification_index + 1) % @clarification_options.size
        end

        def selected_clarification_option
          @clarification_options[@clarification_index]
        end

        def toggle_clarification_input_mode!
          @clarification_input_mode = @clarification_input_mode == :options ? :custom : :options
        end

        def append_to_clarification_input(text)
          @clarification_custom_input << text
        end

        def delete_last_clarification_char
          @clarification_custom_input.chop!
        end

        private

        def reset_clarification_state
          @clarification_question = nil
          @clarification_options = []
          @clarification_index = 0
          @clarification_custom_input = String.new
          @clarification_input_mode = :options
        end
      end
    end
  end
end
