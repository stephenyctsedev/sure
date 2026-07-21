class PwaController < ApplicationController
  skip_authentication

  # The manifest and service worker are public, GET-only static assets that contain
  # no per-user data. With forgery protection active, Rails marks GET requests for
  # same-origin verification and its after_action (verify_same_origin_request) raises
  # InvalidCrossOriginRequest for the JS service worker whenever the request looks
  # cross-origin — which happens routinely for self-hosted instances accessed over
  # plain HTTP or behind a reverse proxy (e.g. an http:// browser origin vs. an
  # assume_ssl https:// computed origin), breaking SW registration. Skipping forgery
  # protection here also disables that same-origin <script> check (the after_action
  # only fires when the token before_action marked the request). Browsers already
  # require service workers to be same-origin, so this removes no real protection.
  skip_forgery_protection

  def manifest
    # Force JSON format to avoid MissingTemplate errors when browsers request /manifest
    # with HTML Accept headers (Safari Mobile does this for PWA manifest discovery)
    render "pwa/manifest", formats: [ :json ], content_type: "application/manifest+json"
  end

  def service_worker
    # Explicitly render JS template to avoid format negotiation issues
    render "pwa/service-worker", formats: [ :js ], content_type: "application/javascript"
  end
  # Renders app/views/pwa/service-worker.js with content type application/javascript
end
