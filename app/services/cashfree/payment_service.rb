require "net/http"
require "uri"
require "json"
require "openssl"

module Cashfree
  class PaymentService
    class Error < StandardError; end

    def self.cf_environment
      env = ENV["CASHFREE_ENV"].to_s.strip.upcase
      if env.present?
        %w[PROD PRODUCTION].include?(env) ? "PRODUCTION" : "SANDBOX"
      elsif ENV["CASHFREE_BASE"].to_s.include?("api.cashfree.com")
        "PRODUCTION"
      else
        "SANDBOX"
      end
    end

    def self.base_url
      return ENV["CASHFREE_BASE"] if ENV["CASHFREE_BASE"].present?

      cf_environment == "PRODUCTION" ? "https://api.cashfree.com/pg" : "https://sandbox.cashfree.com/pg"
    end

    def self.create_order(amount:, order_id:, customer:)
      api_url = URI.parse("#{base_url}/orders")

      phone_digits = customer.phone.to_s.gsub(/\D/, "")
      phone_digits = "9999999999" if phone_digits.length < 10

      email_str = customer.email.presence || "customer#{customer.id}@previewtax.com"
      name_str = customer.full_name.presence || customer.username.presence || "Customer #{customer.id}"
      return_url_template = "previewtax://payment-status?order_id={order_id}"

      body = {
        order_id: order_id,
        order_amount: format("%.2f", amount.to_f),
        order_currency: "INR",
        order_note: "Wallet top-up for account #{customer.id}",
        customer_details: {
          customer_id: "cust_#{customer.id}",
          customer_name: name_str,
          customer_email: email_str,
          customer_phone: phone_digits,
        },
        order_meta: {
          return_url: return_url_template,
        },
      }
      body[:order_meta][:notify_url] = ENV["CASHFREE_NOTIFY_URL"] if ENV["CASHFREE_NOTIFY_URL"].present?

      headers = {
        "Content-Type" => "application/json",
        "x-api-version" => "2023-08-01",
        "x-client-id" => ENV.fetch("CASHFREE_APP_ID"),
        "x-client-secret" => ENV.fetch("CASHFREE_SECRET_KEY"),
      }

      response_body = post_request(api_url, body, headers)
      if response_body["order_id"].blank? && response_body["payment_session_id"].blank?
        raise Error, response_body["message"] || response_body["error_description"] || "Cashfree order creation failed"
      end

      session_id = response_body["payment_session_id"]

      {
        order_id: response_body["order_id"] || order_id,
        payment_session_id: session_id,
        order_token: response_body["order_token"] || session_id,
        cf_environment: cf_environment,
      }
    end

    def self.process_webhook!(payload:, signature:)
      verify_webhook!(payload, signature)
      data = JSON.parse(payload)

      order_id = data.fetch("order_id")
      amount = data.fetch("order_amount").to_f.round
      status = data.fetch("order_status")
      account_id = extract_account_id(order_id)

      {
        order_id: order_id,
        status: status,
        amount: amount,
        payment_id: data["payment_id"],
        account_id: account_id,
      }
    rescue JSON::ParserError => error
      raise Error, "Invalid webhook payload: #{error.message}"
    end

    def self.verify_webhook!(payload, signature)
      secret = ENV.fetch("CASHFREE_SECRET_KEY")
      raise Error, "Cashfree webhook secret is not configured" if secret.blank?
      raise Error, "Webhook signature missing" if signature.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
        raise Error, "Invalid Cashfree webhook signature"
      end

      true
    end

    def self.extract_account_id(order_id)
      order_id.to_s.split("_")[1].to_i
    end

    def self.get_order_status(order_id:)
      api_url = URI.parse("#{base_url}/orders/#{order_id}")

      headers = {
        "x-api-version" => "2023-08-01",
        "x-client-id" => ENV.fetch("CASHFREE_APP_ID"),
        "x-client-secret" => ENV.fetch("CASHFREE_SECRET_KEY"),
      }

      request = Net::HTTP::Get.new(api_url)
      headers.each { |k, v| request[k] = v }

      http = Net::HTTP.new(api_url.host, api_url.port)
      http.use_ssl = api_url.scheme == "https"
      response = http.request(request)
      body = JSON.parse(response.body) rescue {}

      status = body["order_status"] || "PENDING"
      amount = body["order_amount"].to_f.round

      {
        order_id: order_id,
        order_status: status,
        amount: amount,
        raw_response: body
      }
    end

    private

    def self.post_request(url, body, headers)
      request = Net::HTTP::Post.new(url)
      headers.each { |k, v| request[k] = v }
      request.body = JSON.generate(body)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      response = http.request(request)
      JSON.parse(response.body)
    rescue StandardError => error
      raise Error, "Cashfree request failed: #{error.message}"
    end
  end
end
