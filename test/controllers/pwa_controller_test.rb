require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  test "manifest responds successfully for html accept headers" do
    get "/manifest", headers: { "Accept" => "text/html" }

    assert_response :success
    assert_equal "application/manifest+json", response.media_type
    assert_includes response.body, '"start_url": "/"'
  end

  # Regression: self-hosted instances accessed over plain HTTP or behind a reverse
  # proxy send an Origin that differs from the app's computed origin. Without
  # disabling the cross-origin JS check on PwaController, the service worker request
  # raises ActionController::InvalidCrossOriginRequest and SW registration breaks.
  test "service worker is served even when the request origin differs from the app origin" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get "/service-worker", headers: { "HTTP_ORIGIN" => "http://different-origin.example.com" }

    assert_response :success
    assert_equal "application/javascript", response.media_type
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
