# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # Core message storage: add, append, clear, and snapshot.
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
            @messages << build_message(role, content)
            @message_generation += 1
            @dirty = true
          end

          scroll_to_bottom
        end

        def build_message(role, content = "")
          { role: role, content: String.new(content.to_s), timestamp: Time.now, **ZERO_TOKEN_USAGE }
        end

        def append_to_last_message(text)
          @mutex.synchronize do
            return if @messages.empty?

            @messages.last[:content] << text.to_s
            @message_generation += 1
            @dirty = true
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
