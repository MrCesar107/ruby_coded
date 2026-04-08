# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # This module contains the logic for the model selection management
      module ModelSelection
        def model_select?
          @mode == :model_select
        end

        def model_select_show_all?
          @model_select_show_all == true
        end

        def enter_model_select!(models, show_all: false)
          @model_list = models
          @model_select_index = 0
          @model_select_filter = String.new
          @model_select_show_all = show_all
          @mode = :model_select
        end

        def exit_model_select!
          @mode = :chat
          @model_list = []
          @model_select_index = 0
          @model_select_filter = String.new
          @model_select_show_all = false
        end

        def model_select_up
          filtered = filtered_model_list
          return if filtered.empty?

          @model_select_index = (@model_select_index - 1) % filtered.size
        end

        def model_select_down
          filtered = filtered_model_list
          return if filtered.empty?

          @model_select_index = (@model_select_index + 1) % filtered.size
        end

        def selected_model
          filtered_model_list[@model_select_index]
        end

        def filtered_model_list
          return @model_list if @model_select_filter.empty?

          query = @model_select_filter.downcase
          @model_list.select do |m|
            model_id = m.respond_to?(:id) ? m.id : m.to_s
            provider = m.respond_to?(:provider) ? m.provider.to_s : ""
            model_id.downcase.include?(query) || provider.downcase.include?(query)
          end
        end

        def append_to_model_filter(text)
          @model_select_filter << text
          @model_select_index = 0
        end

        def delete_last_filter_char
          @model_select_filter.chop!
          @model_select_index = 0
        end
      end
    end
  end
end
