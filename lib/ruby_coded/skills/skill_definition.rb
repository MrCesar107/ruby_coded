# frozen_string_literal: true

module RubyCoded
  module Skills
    # Normalized project-local skill metadata.
    class SkillDefinition
      ATTRIBUTES = %i[name description modes content path priority tags trigger].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(**attrs)
        ATTRIBUTES.each { |attr| instance_variable_set(ivar(attr), attrs[attr]) }
        @modes = Array(@modes).map(&:to_s)
        @tags = Array(@tags).map(&:to_s)
        @priority = (@priority || 0).to_i
      end

      def applies_to_mode?(mode)
        @modes.include?(mode.to_s)
      end

      private

      def ivar(name)
        :"@#{name}"
      end
    end
  end
end
