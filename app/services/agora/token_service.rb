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

  # Implements Agora's "006" AccessToken binary format. Field order and
  # endianness must match the official SDKs exactly (all integers are
  # little-endian; app_id/channel_name/uid are signed as raw bytes, NOT
  # length-prefixed) or the Agora servers will reject the token as invalid.
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
      message = pack_uint32(salt) + pack_uint32(ts) + pack_map(messages)

      to_sign = app_id.to_s.b + channel_name.b + uid.b + message
      signature = OpenSSL::HMAC.digest("sha256", app_certificate, to_sign)

      crc_channel = Zlib.crc32(channel_name)
      crc_uid = Zlib.crc32(uid)

      content = pack_bytes(signature) + pack_uint32(crc_channel) + pack_uint32(crc_uid) + pack_bytes(message)

      "#{VERSION}#{app_id}#{Base64.strict_encode64(content)}"
    end

    private

    # All integers are little-endian per the Agora "006" token spec.
    def pack_uint16(value)
      [value].pack("v")
    end

    def pack_uint32(value)
      [value].pack("V")
    end

    def pack_bytes(bytes)
      pack_uint16(bytes.bytesize) + bytes
    end

    def pack_map(map)
      # Privileges must be written in ascending key order (Java's TreeMap
      # semantics in the reference implementation).
      sorted = map.sort_by { |key, _| key }
      packed = pack_uint16(sorted.size)
      sorted.each do |key, value|
        packed << pack_uint16(key)
        packed << pack_uint32(value)
      end
      packed
    end
  end
end
