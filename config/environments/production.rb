require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  Rails.application.routes.default_url_options[:host] = "https://enquire-4kwv.onrender.com"
  config.active_storage.default_url_options = { host: "https://enquire-4kwv.onrender.com" }

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :cloudinary

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  config.action_cable.url = ENV.fetch("ACTION_CABLE_URL", "wss://enquire-4kwv.onrender.com/cable")
  config.action_cable.allowed_request_origins = ENV.fetch("ACTION_CABLE_ALLOWED_ORIGINS", "https://enquire-4kwv.onrender.com").split(",")

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Durable, DB-backed cache (survives restarts, shared across processes).
  config.cache_store = :solid_cache_store

  # Durable, DB-backed job queue. Jobs are no longer lost on deploy/restart.
  # Processing runs inside Puma when SOLID_QUEUE_IN_PUMA=true (see config/puma.rb);
  # otherwise run a separate `bin/jobs` worker process.
  config.active_job.queue_adapter = :solid_queue
  # Single database — Solid Queue lives in the primary DB, so no connects_to.
  config.solid_queue.silence_polling = true

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV["MAILER_HOST"] || "enquire-4kwv.onrender.com" }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp-relay.brevo.com",
    port: 587,
    domain: "previewtax.com",
    user_name: ENV["BREVO_EMAIL"],
    password: ENV["BREVO_PASS"],
    authentication: "plain",
    enable_starttls_auto: true,
    open_timeout: 60,
    read_timeout: 60
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [
    "enquire-4kwv.onrender.com",
    "previewtax.com",
    /.*\.previewtax\.com/
  ]
  # Allow overriding / adding hosts from the environment without a redeploy.
  config.hosts += ENV.fetch("ADDITIONAL_HOSTS", "").split(",").map(&:strip).reject(&:blank?)

  # Skip DNS rebinding protection for the health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" || request.path == "/" } }
end
