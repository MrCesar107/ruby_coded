# frozen_string_literal: true

require "webrick"
require "timeout"

require_relative "callback_servlet"

module RubyCode
  module Auth
    # This class is used to start a local webrick server for the
    # OAuth authentication callback
    class OAuthCallbackServer
      PORT = 1_455
      TIMEOUT = 120

      def initialize
        @result_queue = Queue.new
        @server = WEBrick::HTTPServer.new(Port: PORT, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
        @server.mount "/auth/callback", CallbackServlet, @result_queue
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
