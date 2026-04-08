# frozen_string_literal: true

module RubyCode
  module Chat
    # Filters deprecated and obsolete models from the selector list.
    # Uses a multi-layered approach: known deprecated patterns,
    # age-based filtering, and latest-alias deduplication.
    module ModelFilter
      DEPRECATED_PATTERNS = [
        /\Agpt-3\.5-turbo/,
        /\Agpt-4-\d{4}/,
        /\Agpt-4-turbo/,
        /\Agpt-4\z/,
        /\Atext-davinci/,
        /\Ababbage/,
        /\Acurie/,
        /\Aada\b/,
        /\Adavinci/,
        /\Aclaude-instant/,
        /\Aclaude-2/,
        /\Aclaude-3-haiku-2024/,
        /\Ao1-preview/,
        /\Ao1-mini/
      ].freeze

      MAX_AGE_SECONDS = 18 * 30 * 24 * 3600

      module_function

      def filter(models)
        models = reject_deprecated_patterns(models)
        models = reject_stale(models)
        deduplicate_latest_aliases(models)
      end

      def reject_deprecated_patterns(models)
        models.reject do |m|
          id = model_id(m)
          DEPRECATED_PATTERNS.any? { |pattern| id.match?(pattern) }
        end
      end

      def reject_stale(models)
        cutoff = Time.now - MAX_AGE_SECONDS
        models.select do |m|
          created = model_created_at(m)
          next true unless created

          id = model_id(m)
          id.include?("latest") || created >= cutoff
        end
      end

      def deduplicate_latest_aliases(models)
        latest_families = Set.new
        models.each do |m|
          id = model_id(m)
          next unless id.end_with?("-latest")

          family = model_family(m)
          latest_families.add("#{model_provider(m)}:#{family}") if family && !family.empty?
        end

        return models if latest_families.empty?

        models.reject do |m|
          id = model_id(m)
          next false if id.end_with?("-latest")

          family = model_family(m)
          next false unless family && !family.empty?

          key = "#{model_provider(m)}:#{family}"
          next false unless latest_families.include?(key)

          snapshot_with_date?(id)
        end
      end

      def model_id(model)
        model.respond_to?(:id) ? model.id.to_s : model.to_s
      end

      def model_created_at(model)
        model.respond_to?(:created_at) ? model.created_at : nil
      end

      def model_family(model)
        model.respond_to?(:family) ? model.family.to_s : ""
      end

      def model_provider(model)
        model.respond_to?(:provider) ? model.provider.to_s : "unknown"
      end

      def snapshot_with_date?(id)
        id.match?(/\d{4}[-_]?\d{2}[-_]?\d{2}/)
      end

      private_class_method :reject_deprecated_patterns, :reject_stale,
                           :deduplicate_latest_aliases, :model_id,
                           :model_created_at, :model_family,
                           :model_provider, :snapshot_with_date?
    end
  end
end
