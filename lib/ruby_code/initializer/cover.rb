# frozen_string_literal: true

module RubyCode
  class Initializer
    # Cover class for printing the cover of the RubyCode gem
    module Cover
      BANNER = <<~'COVER'

             /\
            /  \
           /    \         ____        _              ____          _
          /------\       |  _ \ _   _| |__  _   _   / ___|___   __| | ___
         /  \  /  \      | |_) | | | | '_ \| | | | | |   / _ \ / _` |/ _ \
        /    \/    \     |  _ <| |_| | |_) | |_| | | |__| (_) | (_| |  __/
        \    /\    /     |_| \_\\__,_|_.__/ \__, |  \____\___/ \__,_|\___|
         \  /  \  /                         |___/
          \/    \/
           \    /                           v%<version>s
            \  /
             \/

      COVER

      def self.print_cover_message
        BANNER.sub("%<version>s", RubyCode::VERSION)
      end
    end
  end
end
