require "net/http"
require "uri"
require "json"
require "openssl"

module Cashfree
  class PaymentService
    class Error < StandardError; end

    def self.create_order(amount_cents:, order_id:, customer:)
      base_url = ENV.fetch("CASHFREE_BASE", "https://sandbox.cashfree.com/pg")
      api_url = URI.parse("#{base_url}/orders")
      
      body = {
        order_id: order_id,
        order_amount: format("%.2f", amount_cents.to_f / 100.0),
        order_currency: "INR",
        order_note: "Wallet top-up for account #{customer.id}",
        customer_details: {
          customer_id: customer.id.to_s,
          customer_name: customer.full_name || customer.email,
          customer_email: customer.email,
          customer_phone: customer.phone.to_s,
        },
        return_url: ENV.fetch("CASHFREE_RETURN_URL", "https://example.com/payment-success"),
      }

      headers = {
        "Content-Type" => "application/json",
        "x-api-version" => "2023-08-01",
        "x-client-id" => ENV.fetch("CASHFREE_APP_ID"),
        "x-client-secret" => ENV.fetch("CASHFREE_SECRET_KEY"),
      }

      response_body = post_request(api_url, body, headers)
      if response_body["status"] != "OK"
        raise Error, response_body["message"] || "Cashfree order creation failed"
      end

      {
        order_id: response_body["order_id"],
        payment_link: response_body.dig("payment_link", "web") || response_body["payment_link"] || response_body["payment_url"],
        order_token: response_body["order_token"],
      }
    end

    def self.process_webhook!(payload:, signature:)
      verify_webhook!(payload, signature)
      data = JSON.parse(payload)

      order_id = data.fetch("order_id")
      amount_cents = (data.fetch("order_amount").to_f * 100).to_i
      status = data.fetch("order_status")
      account_id = extract_account_id(order_id)

      {
        order_id: order_id,
        status: status,
        amount_cents: amount_cents,
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
