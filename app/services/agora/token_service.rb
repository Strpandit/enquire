require "openssl"
require "securerandom"
require "base64"

module Agora
  class TokenService
    class Error < StandardError; end

    def self.generate(channel_name:, uid:, role: "publisher", expire_seconds: 3600)
      app_id = ENV.fetch("AGORA_APP_ID")
      app_certificate = ENV.fetch("AGORA_APP_CERTIFICATE")
      raise Error, "Missing Agora credentials" if app_id.blank? || app_certificate.blank?

      expire_ts = Time.now.to_i + expire_seconds
      RtcTokenBuilder.build_token(app_id: app_id, app_certificate: app_certificate, channel_name: channel_name, uid: String(uid), role: role, expire_ts: expire_ts)
    end
  end

  class RtcTokenBuilder
    PRIVILEGE_JOIN_CHANNEL = 1
    PRIVILEGE_PUBLISH_AUDIO_STREAM = 2
    PRIVILEGE_PUBLISH_VIDEO_STREAM = 3
    PRIVILEGE_PUBLISH_DATA_STREAM = 4

    def self.build_token(app_id:, app_certificate:, channel_name:, uid:, role:, expire_ts:)
      token = AccessToken.new(app_id, app_certificate, channel_name, uid)
      token.add_privilege(PRIVILEGE_JOIN_CHANNEL, expire_ts)

      if role == "publisher"
        token.add_privilege(PRIVILEGE_PUBLISH_AUDIO_STREAM, expire_ts)
        token.add_privilege(PRIVILEGE_PUBLISH_VIDEO_STREAM, expire_ts)
      end

      token.build
    end
  end

  class AccessToken
    VERSION = "006".freeze

    attr_reader :app_id, :app_certificate, :channel_name, :uid, :salt, :ts, :messages

    def initialize(app_id, app_certificate, channel_name, uid)
      @app_id = app_id
      @app_certificate = app_certificate
      @channel_name = channel_name.to_s
      @uid = uid.to_s
      @salt = SecureRandom.random_number(0xFFFFFFFF)
      @ts = Time.now.to_i
      @messages = {}
    end

    def add_privilege(privilege, expire_timestamp)
      @messages[privilege] = expire_timestamp
    end

    def build
      content = pack_string(app_id) + pack_string(channel_name) + pack_string(uid) + pack_uint32(salt) + pack_uint32(ts) + pack_map(messages)
      signature = OpenSSL::HMAC.digest("sha256", app_certificate, content)
      token_struct = [signature.bytesize].pack("N") + signature + content
      "#{VERSION}#{Base64.strict_encode64(token_struct)}"
    end

    private

    def pack_uint16(value)
      [value].pack("n")
    end

    def pack_uint32(value)
      [value].pack("N")
    end

    def pack_string(value)
      string = value.to_s
      pack_uint16(string.bytesize) + string
    end

    def pack_map(map)
      packed = pack_uint16(map.size)
      map.each do |key, value|
        packed << pack_uint16(key)
        packed << pack_uint32(value)
      end
      packed
    end
  end
end
