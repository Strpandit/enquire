require "openssl"
require "securerandom"
require "base64"
require "zlib"

module Agora
  class TokenService
    class Error < StandardError; end

    def self.generate(channel_name:, uid:, role: "publisher", expire_seconds: 3600)
      app_id = ENV.fetch("AGORA_APP_ID")
      app_certificate = ENV.fetch("AGORA_APP_CERTIFICATE")
      raise Error, "Missing Agora credentials" if app_id.blank? || app_certificate.blank?

      RtcTokenBuilder.build_token(
        app_id: app_id,
        app_certificate: app_certificate,
        channel_name: channel_name,
        uid: String(uid),
        role: role,
        expire_seconds: expire_seconds
      )
    end
  end

  class RtcTokenBuilder
    PRIVILEGE_JOIN_CHANNEL = 1
    PRIVILEGE_PUBLISH_AUDIO_STREAM = 2
    PRIVILEGE_PUBLISH_VIDEO_STREAM = 3
    PRIVILEGE_PUBLISH_DATA_STREAM = 4

    def self.build_token(app_id:, app_certificate:, channel_name:, uid:, role:, expire_seconds:)
      token = AccessToken2.new(app_id: app_id, app_certificate: app_certificate, expire_seconds: expire_seconds)
      service = ServiceRtc.new(channel_name: channel_name, uid: uid)
      service.add_privilege(PRIVILEGE_JOIN_CHANNEL, expire_seconds)

      if role == "publisher"
        service.add_privilege(PRIVILEGE_PUBLISH_AUDIO_STREAM, expire_seconds)
        service.add_privilege(PRIVILEGE_PUBLISH_VIDEO_STREAM, expire_seconds)
      end

      token.add_service(service)
      token.build
    end
  end

  module BytePacking
    module_function

    def pack_uint16(value)
      [ value ].pack("v")
    end

    def pack_uint32(value)
      [ value ].pack("V")
    end

    def pack_bytes(bytes)
      pack_uint16(bytes.bytesize) + bytes
    end

    def pack_string(str)
      pack_bytes(str.to_s.b)
    end
  end

  RTC_SERVICE_TYPE = 1

  class ServiceRtc
    include BytePacking

    def initialize(channel_name:, uid:)
      @channel_name = channel_name.to_s
      @uid = uid.to_s == "0" ? "" : uid.to_s
      @privileges = {}
    end

    def add_privilege(privilege, expire_seconds)
      @privileges[privilege] = expire_seconds
    end

    def pack
      pack_type + pack_privileges + pack_string(@channel_name) + pack_string(@uid)
    end

    private

    def pack_type
      pack_uint16(RTC_SERVICE_TYPE)
    end

    def pack_privileges
      sorted = @privileges.sort_by { |key, _| key }
      packed = pack_uint16(sorted.size)
      sorted.each do |key, value|
        packed << pack_uint16(key)
        packed << pack_uint32(value)
      end
      packed
    end
  end

  class AccessToken2
    include BytePacking
    VERSION = "007".freeze

    def initialize(app_id:, app_certificate:, expire_seconds:)
      @app_id = app_id
      @app_certificate = app_certificate
      @issue_ts = Time.now.to_i
      @expire_seconds = expire_seconds
      @salt = SecureRandom.random_number(99_999_999) + 1
      @services = []
    end

    def add_service(service)
      @services << service
    end

    def build
      signing_info = pack_string(@app_id) +
                     pack_uint32(@issue_ts) +
                     pack_uint32(@expire_seconds) +
                     pack_uint32(@salt) +
                     pack_uint16(@services.size)
      @services.each { |service| signing_info << service.pack }

      signature = OpenSSL::HMAC.digest("sha256", signing_key, signing_info)
      content = pack_bytes(signature) + signing_info
      compressed = Zlib::Deflate.deflate(content)

      "#{VERSION}#{Base64.strict_encode64(compressed)}"
    end

    private

    def signing_key
      step1 = OpenSSL::HMAC.digest("sha256", pack_uint32(@issue_ts), @app_certificate)
      OpenSSL::HMAC.digest("sha256", pack_uint32(@salt), step1)
    end
  end
end
