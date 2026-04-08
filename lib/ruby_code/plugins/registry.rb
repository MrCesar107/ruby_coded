# frozen_string_literal: true

module RubyCode
  module Plugins
    # Stores registered plugins and provides access to their extensions.
    # Used by Chat::App at boot time to wire everything together.
    class Registry
      attr_reader :plugins

      def initialize
        @plugins = []
      end

      def register(plugin_class)
        validate!(plugin_class)
        return if @plugins.include?(plugin_class)

        @plugins << plugin_class
      end

      def state_extensions
        @plugins.filter_map(&:state_extension)
      end

      def input_extensions
        @plugins.filter_map(&:input_extension)
      end

      def renderer_extensions
        @plugins.filter_map(&:renderer_extension)
      end

      def command_handler_extensions
        @plugins.filter_map(&:command_handler_extension)
      end

      # Returns an array of { method: Symbol } for each plugin that
      # contributes an input handler hook.
      def input_handler_configs
        @plugins.filter_map do |plugin|
          next unless plugin.input_handler_method

          { method: plugin.input_handler_method }
        end
      end

      # Returns an array of { method: Symbol } for each plugin that
      # contributes a render overlay.
      def render_configs
        @plugins.filter_map do |plugin|
          next unless plugin.render_method

          { method: plugin.render_method }
        end
      end

      def all_commands
        @plugins.each_with_object({}) { |p, h| h.merge!(p.commands) }
      end

      def all_command_descriptions
        @plugins.each_with_object({}) { |p, h| h.merge!(p.command_descriptions) }
      end

      # Includes all plugin modules into the target classes in one pass.
      def apply_extensions!(state_class:, input_handler_class:, renderer_class:, command_handler_class:)
        safe_include(state_class, state_extensions)
        safe_include(input_handler_class, input_extensions)
        safe_include(renderer_class, renderer_extensions)
        safe_include(command_handler_class, command_handler_extensions)
      end

      private

      def validate!(plugin_class)
        return if plugin_class.is_a?(Class) && plugin_class < Base

        raise ArgumentError, "#{plugin_class} must be a subclass of RubyCode::Plugins::Base"
      end

      def safe_include(target_class, modules)
        modules.each do |mod|
          target_class.include(mod) unless target_class.ancestors.include?(mod)
        end
      end
    end
  end
end
