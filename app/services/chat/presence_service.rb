module Chat
  class PresenceService
    PRESENCE_TTL = 2.minutes

    def self.mark_online!(account)
      Rails.cache.write(cache_key(account.id), true, expires_in: PRESENCE_TTL)
      account.update_column(:last_seen_at, Time.current)
    end

    def self.mark_offline!(account)
      Rails.cache.delete(cache_key(account.id))
      account.update_column(:last_seen_at, Time.current)
    end

    def self.online?(account_id)
      Rails.cache.read(cache_key(account_id)) == true
    end

    def self.cache_key(account_id)
      "account_presence:#{account_id}"
    end
  end
end
