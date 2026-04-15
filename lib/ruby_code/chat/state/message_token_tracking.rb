# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # Tracks per-message and per-model token usage counters.
      module MessageTokenTracking
        TOKEN_KEYS = %i[input_tokens output_tokens thinking_tokens cached_tokens cache_creation_tokens].freeze

        def update_last_message_tokens(model: nil, **token_counts)
          @mutex.synchronize do
            return if @messages.empty?

            counts = TOKEN_KEYS.to_h { |key| [key, token_counts[key].to_i] }
            apply_token_counts(@messages.last, counts)
            accumulate_token_counts(model || @model, counts)
          end
        end

        def total_input_tokens
          @mutex.synchronize do
            @messages.sum { |message| message[:input_tokens] }
          end
        end

        def total_output_tokens
          @mutex.synchronize do
            @messages.sum { |message| message[:output_tokens] }
          end
        end

        def total_thinking_tokens
          @mutex.synchronize do
            @messages.sum { |message| message[:thinking_tokens] }
          end
        end

        def token_usage_by_model
          @mutex.synchronize do
            @token_usage_by_model.transform_values(&:dup)
          end
        end

        private

        def apply_token_counts(message, counts)
          counts.each { |key, value| message[key] = value }
        end

        def accumulate_token_counts(model, counts)
          usage = @token_usage_by_model[model]
          counts.each { |key, value| usage[key] += value }
        end
      end
    end
  end
end
