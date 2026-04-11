# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # This module contains the logic for the chats messages management
      module Messages
        attr_reader :message_generation

        ZERO_TOKEN_USAGE = {
          input_tokens: 0, output_tokens: 0,
          thinking_tokens: 0, cached_tokens: 0, cache_creation_tokens: 0
        }.freeze

        def init_messages
          @message_generation = 0
          @snapshot_cache = nil
          @snapshot_cache_gen = -1
          @token_usage_by_model = Hash.new { |h, k| h[k] = ZERO_TOKEN_USAGE.dup }
        end

        def add_message(role, content)
          @mutex.synchronize do
            @messages << {
              role: role,
              content: String.new(content.to_s),
              timestamp: Time.now,
              **ZERO_TOKEN_USAGE
            }
            @message_generation += 1
            @dirty = true
          end

          scroll_to_bottom
        end

        def append_to_last_message(text)
          @mutex.synchronize do
            return if @messages.empty?

            @messages.last[:content] << text.to_s
            @message_generation += 1
            @dirty = true
          end
        end

        # Ensures the last message is :assistant so streaming chunks
        # land in the right place after tool call/result messages.
        def ensure_last_is_assistant!
          @mutex.synchronize do
            return if !@messages.empty? && @messages.last[:role] == :assistant

            @messages << {
              role: :assistant,
              content: String.new,
              timestamp: Time.now,
              **ZERO_TOKEN_USAGE
            }
            @message_generation += 1
            @dirty = true
          end
        end

        # Single-mutex operation combining ensure_last_is_assistant! + append.
        def streaming_append(text)
          @mutex.synchronize do
            if @messages.empty? || @messages.last[:role] != :assistant
              @messages << {
                role: :assistant,
                content: String.new,
                timestamp: Time.now,
                **ZERO_TOKEN_USAGE
              }
            end
            @messages.last[:content] << text.to_s
            @message_generation += 1
            @dirty = true
          end
        end

        def last_assistant_empty?
          @mutex.synchronize do
            return true if @messages.empty?

            last = @messages.last
            last[:role] == :assistant && last[:content].strip.empty?
          end
        end

        def reset_last_assistant_content
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            last[:content] = String.new
            @message_generation += 1
            @dirty = true
          end
        end

        def fail_last_assistant(error, friendly_message: nil)
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            apply_error_to_message(last, friendly_message || "[Error] #{error.class}: #{error.message}")
            @message_generation += 1
            @dirty = true
          end
        end

        def apply_error_to_message(message, err_line)
          if message[:content].strip.empty?
            message[:content] = String.new(err_line)
          else
            message[:content] << "\n\n#{err_line}"
          end
        end

        def update_last_message_tokens(input_tokens:, output_tokens:, model: nil,
                                       thinking_tokens: nil, cached_tokens: nil,
                                       cache_creation_tokens: nil)
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            last[:input_tokens] = input_tokens
            last[:output_tokens] = output_tokens
            last[:thinking_tokens] = thinking_tokens.to_i
            last[:cached_tokens] = cached_tokens.to_i
            last[:cache_creation_tokens] = cache_creation_tokens.to_i

            usage = @token_usage_by_model[model || @model]
            usage[:input_tokens] += input_tokens.to_i
            usage[:output_tokens] += output_tokens.to_i
            usage[:thinking_tokens] += thinking_tokens.to_i
            usage[:cached_tokens] += cached_tokens.to_i
            usage[:cache_creation_tokens] += cache_creation_tokens.to_i
          end
        end

        def clear_messages!
          @mutex.synchronize do
            @messages.clear
            @token_usage_by_model.clear
            @message_generation += 1
            @dirty = true
          end
          @scroll_offset = 0
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

        def messages_snapshot
          @mutex.synchronize do
            return @snapshot_cache if @snapshot_cache_gen == @message_generation

            @snapshot_cache = @messages.map do |msg|
              msg.dup.tap { |m| m[:content] = m[:content].dup }
            end
            @snapshot_cache_gen = @message_generation
            @snapshot_cache
          end
        end
      end
    end
  end
end
