# frozen_string_literal: true

require_relative "../model_filter"
require_relative "../codex_models"
require_relative "../../auth/jwt_decoder"

module RubyCoded
  module Chat
    class CommandHandler
      # This module contains the logic for the CLI commands' management
      module ModelCommands
        private

        def cmd_model(rest)
          return open_model_selector if rest.nil? || rest.strip.empty?

          name = rest.strip
          return open_model_selector(show_all: true) if name == "--all"
          return unless model_match?(name)

          switch_to_model(name)
        rescue StandardError => e
          @state.add_message(:system, "Failed to switch model: #{e.message}")
        end

        def model_match?(name)
          models = fetch_chat_models
          return true unless models.any?
          return true if models.find { |m| model_id(m) == name }

          suggest_models(name, models)
          false
        end

        def suggest_models(name, models)
          suggestions = models.select { |m| model_id(m).include?(name) }.map { |m| model_id(m) }.first(5)
          msg = "Model '#{name}' not found."
          msg += " Did you mean: #{suggestions.join(", ")}?" if suggestions.any?
          @state.add_message(:system, msg)
        end

        def switch_to_model(name)
          @state.model = name
          @llm_bridge.reset_chat!(name)
          @user_config&.set_config("model", name)
          @state.add_message(:system, "Model switched to #{name}.")
        end

        def open_model_selector(show_all: false)
          models = fetch_models_for_authenticated_providers
          models = ModelFilter.filter(models) unless show_all || codex_oauth_active?

          if models.empty?
            @state.add_message(:system,
                               "Current model: #{@state.model}. " \
                               "No available models found for your authenticated providers.")
            return
          end

          @state.enter_model_select!(models, show_all: show_all)
        end

        def fetch_models_for_authenticated_providers
          return fetch_chat_models unless @credentials_store

          models = []
          Auth::AuthManager::PROVIDERS.each_key do |name|
            creds = @credentials_store.retrieve(name)
            models.concat(models_for_provider(name, creds)) if creds
          end
          models
        rescue StandardError
          fetch_chat_models
        end

        def models_for_provider(name, creds)
          if name == :openai && creds["auth_method"] == "oauth"
            codex_models_for_plan(creds)
          else
            RubyLLM.models.by_provider(name).chat_models.to_a
          end
        end

        def codex_models_for_plan(creds)
          token = creds["access_token"]
          plan = token ? Auth::JWTDecoder.extract_plan_type(token) : nil
          CodexModels.available_for_plan(plan)
        end

        def fetch_chat_models
          RubyLLM.models.chat_models.to_a
        rescue StandardError
          []
        end

        def model_id(model)
          return model.id if model.respond_to?(:id)

          model.to_s
        end

        def codex_oauth_active?
          return false unless @credentials_store

          creds = @credentials_store.retrieve(:openai)
          creds && creds["auth_method"] == "oauth"
        end
      end
    end
  end
end
