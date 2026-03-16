# frozen_string_literal: true

module RubyCode
  module Auth
    class CallbackServlet < WEBrick::HTTPServlet::AbstractServlet
      def initialize(server, result_queue)
        super(server)
        @result_queue = result_queue
      end

      def do_GET(request, response)
        code = request.query["code"]
        state = request.query["state"]
        error = request.query["error"]

        if error
          @result_queue.push({ error: error })
        else
          @result_queue.push({ code: code, state: state })
        end

        response.status = 200
        response.content_type = "text/html"
        response.body = <<~HTML
          <html>
            <body>
              <h2>You are now logged</h2>
              <p>You can close this window now.</p>
              <script>window.close();/script>
            </body>
          </html>
        HTML
      end
    end
  end
end
