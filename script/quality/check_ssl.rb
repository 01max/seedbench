require "rack/mock"

abort "Use the production SSL probe configuration" unless
  Rails.env.production? && Rails.application.config.force_ssl && !Rails.application.config.assume_ssl

requests = Rack::MockRequest.new(Rails.application)
health = requests.get("/up", "HTTP_HOST" => "127.0.0.1")
abort "HTTP health check returned #{health.status}" unless health.status == 200

shell = requests.get("/session/new", "HTTP_HOST" => "127.0.0.1")
abort "Application HTTPS redirect missing" unless
  shell.status == 301 && shell["location"] == "https://127.0.0.1/session/new"

proxied = requests.get("/session/new", "HTTP_HOST" => "127.0.0.1", "HTTP_X_FORWARDED_PROTO" => "https")
abort "HTTPS proxy request failed" unless proxied.status == 200 && proxied.body.include?("Seedbench")

puts "HTTP health checks, application HTTPS redirects, and forwarded HTTPS requests verified."
