# frozen_string_literal: true

require "webrick"

require_relative "callback_servlet"

module RubyCode
  module Auth
    class OAuthCallbackServer
      PORT = 18_192
      TIMEOUT = 120

      def initialize
        @result_queue = Queue.new
        @server = WEBrick::HTTPServer.new(Port: PORT, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
        @server.mount "/callback", CallbackServlet, @result_queue
      end

      def start
        @thread = Thread.new { @server.start }
      end

      def wait_for_callback
        Timeout.timeout(TIMEOUT) { @result_queue.pop }
      ensure
        shutdown
      end

      def shutdown
        @server.shutdown
        @thread&.join(5)
      end
    end
  end
end
