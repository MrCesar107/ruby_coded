# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # Shared formatting helpers for token and cost display.
      module TokenFormatting
        private

        def format_num(num)
          num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
        end

        def format_usd(amount)
          return "N/A" if amount.nil?

          "$#{format("%.2f", amount)}"
        end

        def cost_string(cost)
          cost ? format_usd(cost) : "N/A"
        end
      end
    end
  end
end
