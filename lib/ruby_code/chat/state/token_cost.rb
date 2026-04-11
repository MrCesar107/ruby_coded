# frozen_string_literal: true

require "ruby_llm"

module RubyCode
  module Chat
    class State
      # Provides session cost calculation based on token usage and model pricing.
      # Looks up per-model pricing via RubyLLM's model registry.
      # Accounts for thinking/reasoning tokens, cached input reads, and
      # cache creation tokens in addition to regular input/output.
      module TokenCost
        # Anthropic charges 1.25× input price for cache writes.
        # OpenAI reports cache_creation as 0, so this only affects Anthropic.
        CACHE_CREATION_INPUT_MULTIPLIER = 1.25

        def init_token_cost
          @model_price_cache = {}
        end

        # Returns an array of cost breakdown hashes, one per model used.
        # Cost fields are nil when pricing is unavailable.
        def session_cost_breakdown
          token_usage_by_model.map do |model_name, usage|
            pricing = fetch_model_pricing(model_name)
            build_cost_entry(model_name, usage, pricing)
          end
        end

        def total_session_cost
          breakdown = session_cost_breakdown
          costs = breakdown.map { |entry| entry[:total_cost] }.compact
          return nil if costs.empty?

          costs.sum
        end

        private

        def fetch_model_pricing(model_name)
          return @model_price_cache[model_name] if @model_price_cache.key?(model_name)

          info = RubyLLM.models.find(model_name)
          pricing = if info && info.respond_to?(:input_price_per_million) && info.input_price_per_million
                      build_pricing_hash(info)
                    end
          @model_price_cache[model_name] = pricing
          pricing
        rescue StandardError
          @model_price_cache[model_name] = nil
          nil
        end

        def build_pricing_hash(info)
          input_price = info.input_price_per_million.to_f
          output_price = info.output_price_per_million.to_f
          text_tokens = info.pricing.text_tokens
          cached_price = text_tokens.respond_to?(:cached_input) && text_tokens.cached_input \
                         ? text_tokens.cached_input.to_f : nil
          thinking_price = resolve_thinking_price(text_tokens, output_price)

          {
            input_price_per_million: input_price,
            output_price_per_million: output_price,
            thinking_price_per_million: thinking_price,
            cached_input_price_per_million: cached_price,
            cache_creation_price_per_million: input_price * CACHE_CREATION_INPUT_MULTIPLIER
          }
        end

        def resolve_thinking_price(text_tokens, output_price)
          standard = text_tokens.standard
          if standard && standard.respond_to?(:reasoning_output_per_million) && standard.reasoning_output_per_million
            standard.reasoning_output_per_million.to_f
          else
            output_price
          end
        end

        def build_cost_entry(model_name, usage, pricing)
          if pricing
            build_priced_entry(model_name, usage, pricing)
          else
            build_unpriced_entry(model_name, usage)
          end
        end

        def build_priced_entry(model_name, usage, pricing)
          input_cost = token_cost(usage[:input_tokens], pricing[:input_price_per_million])
          output_cost = token_cost(usage[:output_tokens], pricing[:output_price_per_million])
          thinking_cost = token_cost(usage[:thinking_tokens], pricing[:thinking_price_per_million])
          cached_cost = pricing[:cached_input_price_per_million] \
                        ? token_cost(usage[:cached_tokens], pricing[:cached_input_price_per_million]) : 0.0
          cache_creation_cost = token_cost(usage[:cache_creation_tokens],
                                           pricing[:cache_creation_price_per_million])

          {
            model: model_name,
            input_tokens: usage[:input_tokens],
            output_tokens: usage[:output_tokens],
            thinking_tokens: usage[:thinking_tokens],
            cached_tokens: usage[:cached_tokens],
            cache_creation_tokens: usage[:cache_creation_tokens],
            input_price_per_million: pricing[:input_price_per_million],
            output_price_per_million: pricing[:output_price_per_million],
            thinking_price_per_million: pricing[:thinking_price_per_million],
            cached_input_price_per_million: pricing[:cached_input_price_per_million],
            cache_creation_price_per_million: pricing[:cache_creation_price_per_million],
            input_cost: input_cost,
            output_cost: output_cost,
            thinking_cost: thinking_cost,
            cached_cost: cached_cost,
            cache_creation_cost: cache_creation_cost,
            total_cost: input_cost + output_cost + thinking_cost + cached_cost + cache_creation_cost
          }
        end

        def build_unpriced_entry(model_name, usage)
          {
            model: model_name,
            input_tokens: usage[:input_tokens],
            output_tokens: usage[:output_tokens],
            thinking_tokens: usage[:thinking_tokens],
            cached_tokens: usage[:cached_tokens],
            cache_creation_tokens: usage[:cache_creation_tokens],
            input_price_per_million: nil,
            output_price_per_million: nil,
            thinking_price_per_million: nil,
            cached_input_price_per_million: nil,
            cache_creation_price_per_million: nil,
            input_cost: nil,
            output_cost: nil,
            thinking_cost: nil,
            cached_cost: nil,
            cache_creation_cost: nil,
            total_cost: nil
          }
        end

        def token_cost(count, price_per_million)
          (count.to_f / 1_000_000) * price_per_million
        end
      end
    end
  end
end
