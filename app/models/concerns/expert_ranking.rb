module ExpertRanking
  extend ActiveSupport::Concern

  CONSULTATION_WINDOW = 90.days
  SORTS = %w[recommended popular top_rated price_low available].freeze
  DEFAULT_SORT = "recommended"

  VERIFIED_SQL = <<~SQL.squish.freeze
    EXISTS (
      SELECT 1 FROM accounts a
      WHERE a.id = business_profiles.account_id
        AND a.deleted_at IS NULL
        AND (
          a.is_verified = TRUE
          OR (a.verification_status = 2 AND a.verified_at IS NOT NULL
              AND a.verified_at + INTERVAL '180 days' > NOW())
        )
    )
  SQL

  MIN_PRICE_SQL = <<~SQL.squish.freeze
    LEAST(NULLIF(business_profiles.chat_price, 0),
          NULLIF(business_profiles.call_price, 0),
          NULLIF(business_profiles.v_call_price, 0))
  SQL

  class_methods do
    def ranked(sort)
      sort = DEFAULT_SORT unless SORTS.include?(sort.to_s)

      verified = "(#{VERIFIED_SQL})"
      consultations = "(#{consultations_sql})"
      rating = "business_profiles.avg_rating"
      price = "(#{MIN_PRICE_SQL})"

      terms =
        case sort.to_s
        when "popular"
          [ "#{verified} DESC", "#{consultations} DESC", "#{rating} DESC" ]
        when "top_rated"
          [ "#{rating} DESC", "business_profiles.reviews_count DESC", "#{verified} DESC", "#{consultations} DESC" ]
        when "price_low"
          [ "#{price} ASC NULLS LAST", "#{verified} DESC", "#{consultations} DESC", "#{rating} DESC" ]
        when "available"
          [ "(#{available_sql}) DESC", "#{verified} DESC", "#{consultations} DESC", "#{rating} DESC" ]
        else # recommended
          [ "#{verified} DESC", "#{consultations} DESC", "#{rating} DESC", "#{price} ASC NULLS LAST" ]
        end

      order(Arel.sql((terms + [ "business_profiles.id ASC" ]).join(", ")))
    end

    private

    def consultations_sql
      since = connection.quote(CONSULTATION_WINDOW.ago)
      <<~SQL.squish
        SELECT COUNT(*) FROM (
          SELECT ch.caller_account_id FROM call_histories ch
          WHERE ch.receiver_account_id = business_profiles.account_id
            AND ch.status IN (1, 2) AND ch.started_at >= #{since}
          UNION
          SELECT cs.customer_account_id FROM chat_sessions cs
          WHERE cs.business_profile_id = business_profiles.id
            AND cs.status IN (1, 2) AND cs.started_at >= #{since}
        ) consultations
      SQL
    end

    def available_sql
      now = Time.current.in_time_zone(Time.zone)
      wday = connection.quote(now.wday)
      clock = connection.quote(now.strftime("%H:%M:%S"))
      <<~SQL.squish
        business_profiles.is_available = TRUE AND (
          NOT EXISTS (SELECT 1 FROM schedules s WHERE s.business_profile_id = business_profiles.id AND s.availability_type = 0)
          OR EXISTS (SELECT 1 FROM schedules s WHERE s.business_profile_id = business_profiles.id AND s.availability_type = 1)
          OR EXISTS (SELECT 1 FROM schedules s WHERE s.business_profile_id = business_profiles.id AND s.availability_type = 0
                     AND s.day_of_week = #{wday} AND s.start_time <= #{clock}::time AND s.end_time > #{clock}::time)
        )
      SQL
    end
  end
end
