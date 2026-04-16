# frozen_string_literal: true

require_relative "renderer/chat_panel"
require_relative "renderer/chat_panel_thinking"
require_relative "renderer/chat_panel_input"
require_relative "renderer/model_selector"
require_relative "renderer/plan_clarifier_layout"
require_relative "renderer/plan_clarifier"
require_relative "renderer/login_flow_layout"
require_relative "renderer/login_flow"
require_relative "renderer/status_bar"

module RubyCoded
  module Chat
    # This class manages the rendering of the UI elements
    class Renderer
      include ChatPanel
      include ChatPanelThinking
      include ChatPanelInput
      include ModelSelector
      include PlanClarifierLayout
      include PlanClarifier
      include LoginFlowLayout
      include LoginFlow
      include StatusBar

      def initialize(tui, state)
        @tui = tui
        @state = state
      end

      def draw
        @tui.clear

        @tui.draw do |frame|
          chat_area, status_area, input_area = main_layout(frame)
          render_chat_panel(frame, chat_area)
          render_status_bar(frame, status_area)
          render_input_panel(frame, input_area)
          render_overlays(frame, chat_area, input_area)
        end
      end

      private

      def render_overlays(frame, chat_area, input_area)
        render_model_selector(frame, chat_area) if @state.model_select?
        render_plan_clarifier(frame, chat_area) if @state.plan_clarification?
        render_login_flow(frame, chat_area) if @state.login_active?
        render_plugin_overlays(frame, chat_area, input_area)
      end

      # Calls each plugin's render method in registration order.
      def render_plugin_overlays(frame, chat_area, input_area)
        RubyCoded.plugin_registry.render_configs.each do |config|
          send(config[:method], frame, chat_area, input_area)
        end
      end

      def main_layout(frame)
        @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_fill(1),
            @tui.constraint_length(1),
            @tui.constraint_length(3)
          ]
        )
      end
    end
  end
end
