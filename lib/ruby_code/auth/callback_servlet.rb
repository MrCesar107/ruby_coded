# frozen_string_literal: true

module RubyCode
  module Auth
    # This class creates a callback servlet for the OAuth authentication
    class CallbackServlet < WEBrick::HTTPServlet::AbstractServlet
      SUCCESS_HTML = <<~HTML
        <html>
          <body>
            <h2>You are now logged</h2>
            <p>You can close this window now.</p>
            <script>window.close();</script>
          </body>
        </html>
      HTML

      def initialize(server, result_queue)
        super(server)
        @result_queue = result_queue
      end

      def do_GET(request, response) # rubocop:disable Naming/MethodName
        process_callback(request)
        response.status = 200
        response.content_type = "text/html"
        response.body = SUCCESS_HTML
      end

      private

      def process_callback(request)
        error = request.query["error"]
        if error
          @result_queue.push({ error: error })
        else
          @result_queue.push({ code: request.query["code"], state: request.query["state"] })
        end
      end
    end
  end
end
