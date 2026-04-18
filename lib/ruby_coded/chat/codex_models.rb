# frozen_string_literal: true

module RubyCoded
  module Chat
    # Local catalog of models available through the ChatGPT Codex backend.
    # These models are not listed in RubyLLM.models because they use a
    # different API (Responses API via chatgpt.com/backend-api).
    module CodexModels
      PROVIDER = :openai

      CodexModel = Struct.new(:id, :display_name, :context_window, :max_output, :pro_only,
                              keyword_init: true) do
        def to_s
          id
        end

        def provider
          PROVIDER
        end

        def pro_only?
          pro_only == true
        end
      end

      MODELS = [
        CodexModel.new(id: "gpt-5.4", display_name: "GPT 5.4 (Recommended)",
                       context_window: 272_000, max_output: 128_000, pro_only: false),
        CodexModel.new(id: "gpt-5.4-mini", display_name: "GPT 5.4 Mini",
                       context_window: 272_000, max_output: 128_000, pro_only: false),
        CodexModel.new(id: "gpt-5.3-codex-spark", display_name: "GPT 5.3 Codex Spark",
                       context_window: 272_000, max_output: 128_000, pro_only: true),
        CodexModel.new(id: "gpt-5.2-codex", display_name: "GPT 5.2 Codex",
                       context_window: 272_000, max_output: 128_000, pro_only: true),
        CodexModel.new(id: "gpt-5.2", display_name: "GPT 5.2",
                       context_window: 272_000, max_output: 128_000, pro_only: false)
      ].freeze

      def self.all
        MODELS
      end

      def self.find(id)
        MODELS.find { |m| m.id == id }
      end

      def self.codex_model?(id)
        MODELS.any? { |m| m.id == id }
      end

      def self.pro_only?(id)
        model = find(id)
        model ? model.pro_only? : false
      end

      PRO_TIER_PLANS = %w[pro team enterprise business edu].freeze

      def self.available_for_plan(plan)
        normalized = plan.to_s.downcase
        return MODELS if normalized.empty? || PRO_TIER_PLANS.any? { |p| normalized.include?(p) }

        if normalized.include?("plus") || normalized.include?("free")
          MODELS.reject(&:pro_only?)
        else
          MODELS
        end
      end
    end
  end
end
