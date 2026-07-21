class PwaController < ApplicationController
  skip_authentication

  # The manifest and service worker are public, GET-only static assets that contain
  # no per-user data. Rails' cross-origin JavaScript protection
  # (verify_same_origin_request) otherwise raises InvalidCrossOriginRequest for the
  # JS service worker whenever the request's Origin does not match the app's computed
  # origin — which happens routinely for self-hosted instances accessed over plain
  # HTTP or behind a reverse proxy (e.g. an http:// browser origin vs. an assume_ssl
  # https:// computed origin). Browsers already require service workers to be
  # same-origin, so this check adds no security here while breaking SW registration.
  self.forgery_protection_origin_check = false

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
