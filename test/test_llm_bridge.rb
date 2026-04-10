# frozen_string_literal: true

require "test_helper"
require "ruby_llm"
require "ruby_code/chat/llm_bridge"
require "ruby_code/chat/state"

class TestLLMBridge < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "test-model")
  end

  def test_attempt_with_retries_succeeds_on_first_try
    response = mock_response(content: "Hello!", input_tokens: 5, output_tokens: 2)
    chat = build_chat(responses: [response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    result = bridge.send(:attempt_with_retries, chat, "Hi")

    assert_equal response, result
  end

  def test_attempt_with_retries_retries_on_rate_limit_then_succeeds
    response = mock_response(content: "Hello!", input_tokens: 5, output_tokens: 2)
    chat = build_chat(responses: [rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_equal response, result
    end
  end

  def test_attempt_with_retries_fails_after_max_retries
    chat = build_chat(responses: [rate_limit_error, rate_limit_error, rate_limit_error])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_nil result
    end

    last_msg = @state.messages.last
    assert_includes last_msg[:content], "Límite de peticiones del proveedor"
  end

  def test_attempt_with_retries_does_not_retry_other_errors
    chat = build_chat(responses: [StandardError.new("Connection failed")])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    result = bridge.send(:attempt_with_retries, chat, "Hi")

    assert_nil result
    last_msg = @state.messages.last
    assert_includes last_msg[:content], "Connection failed"
  end

  def test_attempt_with_retries_respects_cancel
    chat = build_chat(responses: [rate_limit_error])
    bridge = build_bridge_with_chat(chat)
    bridge.cancel!

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_nil result
    end
  end

  def test_retry_uses_exponential_backoff
    response = mock_response(content: "OK", input_tokens: 1, output_tokens: 1)
    chat = build_chat(responses: [rate_limit_error, rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    delays = []
    @state.add_message(:assistant, "")
    bridge.stub(:sleep, ->(d) { delays << d }) do
      bridge.send(:attempt_with_retries, chat, "Hi")
    end

    assert_equal [2, 4], delays
  end

  def test_retry_clears_assistant_content_before_retrying
    response = mock_response(content: "Success", input_tokens: 1, output_tokens: 1)
    chat = build_chat(responses: [rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      bridge.send(:attempt_with_retries, chat, "Hi")
    end

    last_msg = @state.messages.last
    assert_equal "Success", last_msg[:content]
  end

  def test_toggle_agentic_mode_preserves_chat_history
    chat = build_configurable_chat
    chat.messages << { role: :user, content: "describe my problem" }
    chat.messages << { role: :assistant, content: "Here is your plan..." }

    bridge = build_bridge_with_configurable_chat(chat)

    bridge.toggle_agentic_mode!(true)

    assert_equal 2, chat.messages.size
    assert_equal "describe my problem", chat.messages[0][:content]
  end

  def test_toggle_plan_mode_preserves_chat_history
    chat = build_configurable_chat
    chat.messages << { role: :user, content: "hello" }
    chat.messages << { role: :assistant, content: "hi there" }

    bridge = build_bridge_with_configurable_chat(chat)

    bridge.toggle_plan_mode!(true)

    assert_equal 2, chat.messages.size
    assert_equal "hello", chat.messages[0][:content]
  end

  def test_switch_from_plan_to_agent_preserves_chat_history
    chat = build_configurable_chat
    chat.messages << { role: :user, content: "plan this feature" }
    chat.messages << { role: :assistant, content: "Here is the plan..." }

    bridge = build_bridge_with_configurable_chat(chat)
    bridge.toggle_plan_mode!(true)

    chat.messages << { role: :user, content: "implement the plan" }

    bridge.toggle_agentic_mode!(true)

    assert_equal 3, chat.messages.size
    assert_equal "Here is the plan...", chat.messages[1][:content]
  end

  def test_reset_chat_creates_new_history
    chat = build_configurable_chat
    chat.messages << { role: :user, content: "old message" }

    new_chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)

    RubyLLM.stub(:chat, new_chat) do
      bridge.reset_chat!("test-model")
    end

    assert_empty new_chat.messages
  end

  def test_auto_switches_to_agent_when_plan_exists_and_user_says_implement
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)
    bridge.toggle_plan_mode!(true)
    @state.update_current_plan!("# My Plan\n- Step 1\n- Step 2")

    assert bridge.plan_mode
    refute bridge.agentic_mode

    result = bridge.send(:should_auto_switch_to_agent?, "implement the plan")

    assert result
  end

  def test_no_auto_switch_without_existing_plan
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)
    bridge.toggle_plan_mode!(true)

    result = bridge.send(:should_auto_switch_to_agent?, "implement the plan")

    refute result
  end

  def test_no_auto_switch_outside_plan_mode
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)

    result = bridge.send(:should_auto_switch_to_agent?, "implement the plan")

    refute result
  end

  def test_implementation_patterns_match_english
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)

    %w[implement execute proceed].each do |word|
      assert bridge.send(:implementation_request?, "please #{word} the plan"),
             "Expected '#{word}' to match"
    end

    ["go ahead", "do it", "build it"].each do |phrase|
      assert bridge.send(:implementation_request?, phrase),
             "Expected '#{phrase}' to match"
    end
  end

  def test_implementation_patterns_match_spanish
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)

    %w[implementa implementar ejecuta hazlo construye comienza adelante].each do |word|
      assert bridge.send(:implementation_request?, word),
             "Expected '#{word}' to match"
    end
  end

  def test_implementation_patterns_reject_unrelated_messages
    chat = build_configurable_chat
    bridge = build_bridge_with_configurable_chat(chat)

    ["add a login page", "what do you think?", "change the database schema",
     "explain step 3", "can you refine the plan?"].each do |msg|
      refute bridge.send(:implementation_request?, msg),
             "Expected '#{msg}' NOT to match"
    end
  end

  private

  def rate_limit_error
    RubyLLM::RateLimitError.new(nil, "Rate limit exceeded")
  end

  def build_bridge_with_chat(chat)
    RubyLLM.stub(:chat, chat) do
      return RubyCode::Chat::LLMBridge.new(@state)
    end
  end

  def build_chat(responses:)
    call_index = 0

    make_chunk = lambda { |content|
      chunk = Object.new
      chunk.define_singleton_method(:content) { content }
      chunk
    }

    chat = Object.new

    chat.define_singleton_method(:with_tools) { |*_args, **_kw| chat }

    chat.define_singleton_method(:ask) do |_input, &block|
      resp = responses[call_index]
      call_index += 1
      raise resp if resp.is_a?(Exception)

      block&.call(make_chunk.call(resp.content)) if resp.respond_to?(:content)
      resp
    end

    chat.define_singleton_method(:complete) do |&block|
      resp = responses[call_index]
      call_index += 1
      raise resp if resp.is_a?(Exception)

      block&.call(make_chunk.call(resp.content)) if resp.respond_to?(:content)
      resp
    end

    chat
  end

  def build_configurable_chat
    chat = Object.new
    msgs = []
    chat.define_singleton_method(:messages) { msgs }
    chat.define_singleton_method(:with_tools) { |*_args, **_kw| chat }
    chat.define_singleton_method(:with_instructions) { |*_args| chat }
    chat.define_singleton_method(:on_tool_call) { |&_blk| chat }
    chat.define_singleton_method(:on_tool_result) { |&_blk| chat }
    chat
  end

  def build_bridge_with_configurable_chat(chat)
    RubyLLM.stub(:chat, chat) do
      return RubyCode::Chat::LLMBridge.new(@state)
    end
  end

  def mock_response(content:, input_tokens:, output_tokens:)
    resp = Object.new
    resp.define_singleton_method(:content) { content }
    resp.define_singleton_method(:input_tokens) { input_tokens }
    resp.define_singleton_method(:output_tokens) { output_tokens }
    resp
  end
end
