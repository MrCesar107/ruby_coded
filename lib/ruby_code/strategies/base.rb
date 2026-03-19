# frozen_string_literal: true

require "tty-prompt"

module RubyCode
  module Strategies
    # Base interface for all authentication strategies
    class Base
      def initialize(provider)
        @provider = provider
        @prompt = TTY::Prompt.new
      end

      def authenticate
        raise NotImplementedError
      end

      def refresh(credentials)
        raise NotImplementedError
      end

      def validate(credentials)
        raise NotImplementedError
      end

      private

      def open_browser(url)
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then system("open", url)
        when /linux/ then system("xdg-open", url)
        when /mswin|mingw/ then system("start", url)
        end
      end
    end
  end
end
