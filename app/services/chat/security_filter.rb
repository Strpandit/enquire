# frozen_string_literal: true

module Chat
  class SecurityFilter
    # Result object for filter analysis
    Result = Struct.new(:violates_policy?, :reasons, :metadata, keyword_init: true)

    # English word to digit mapping
    WORD_TO_DIGIT = {
      "zero" => "0", "oh" => "0", "nil" => "0", "null" => "0",
      "one" => "1", "won" => "1",
      "two" => "2", "to" => "2", "too" => "2",
      "three" => "3", "tree" => "3",
      "four" => "4", "for" => "4", "fore" => "4",
      "five" => "5",
      "six" => "6",
      "seven" => "7",
      "eight" => "8", "ate" => "8",
      "nine" => "9", "niner" => "9",
      # Hindi / Hinglish words
      "shunya" => "0", "sunya" => "0", "sifar" => "0", "sefar" => "0",
      "ek" => "1", "ik" => "1", "aik" => "1",
      "do" => "2", "dou" => "2", "doo" => "2",
      "teen" => "3", "tin" => "3",
      "char" => "4", "chaar" => "4",
      "panch" => "5", "paanch" => "5",
      "chhe" => "6", "che" => "6", "chahe" => "6", "chhey" => "6",
      "saat" => "7", "sat" => "7",
      "aath" => "8", "ath" => "8", "aat" => "8",
      "nau" => "9", "no" => "9", "now" => "9", "nao" => "9"
    }.freeze

    # Devanagari numerals
    DEVANAGARI_DIGITS = {
      "०" => "0", "१" => "1", "२" => "2", "३" => "3", "४" => "4",
      "५" => "5", "६" => "6", "७" => "7", "८" => "8", "९" => "9"
    }.freeze

    # Devanagari words
    DEVANAGARI_WORDS = {
      "शून्य" => "0", "एक" => "1", "दो" => "2", "तीन" => "3", "चार" => "4",
      "पाँच" => "5", "पांच" => "5", "छह" => "6", "सात" => "7", "आठ" => "8", "नौ" => "9"
    }.freeze

    # Common email providers
    EMAIL_PROVIDERS = %w[
      gmail yahoo hotmail outlook icloud rediffmail protonmail zoho
      ymail live aol mail gmx fastmail
    ].freeze

    # Common TLDs
    TLDS = %w[
      com in org net io co ai me info biz app dev xyz online tech
      co\.in org\.in net\.in gov edu
    ].freeze

    # Social / messenger platform identifiers
    SOCIAL_PLATFORMS = %w[
      whatsapp watsapp whats\s*app watsap wa\.me wapp
      telegram tele\s*gram t\.me
      instagram insta ig
      snapchat snap
      skype
      facebook fb\.com
      linkedin
      twitter x\.com
      discord discord\.gg
      zoom zoom\.us
      meet\.google\.com
      trucaller truecaller
    ].freeze

    # Contact trigger keywords
    CONTACT_TRIGGERS = %w[
      call\s*me dial\s*me ping\s*me msg\s*me message\s*me contact\s*me
      reach\s*me text\s*me dm\s*me phone\s*no mobile\s*no contact\s*no
      ph\s*no mob\s*no mera\s*no mera\s*number apna\s*number apna\s*no
      number\s*hai no\s*hai call\s*karo call\s*krna msg\s*karo msg\s*krna
      whatsapp\s*karo wp\s*karo wa\s*karo
    ].freeze

    class << self
      def violation_detected?(content)
        analyze(content).violates_policy?
      end

      def analyze(content)
        return Result.new(violates_policy?: false, reasons: [], metadata: {}) if content.nil? || content.to_s.strip.empty?

        text = content.to_s
        reasons = []

        # 1. Check for standard & obfuscated emails
        email_check = detect_email(text)
        reasons << email_check if email_check

        # 2. Check for URLs / links
        url_check = detect_url(text)
        reasons << url_check if url_check

        # 3. Check for social media handles & redirect keywords
        social_check = detect_social(text)
        reasons << social_check if social_check

        # 4. Check for direct & formatted phone numbers
        phone_check = detect_direct_phone(text)
        reasons << phone_check if phone_check

        # 5. Check for obfuscated / separated phone numbers (spaced digits, special char separation)
        spaced_phone_check = detect_obfuscated_digits(text)
        reasons << spaced_phone_check if spaced_phone_check

        # 6. Check for numbers written in words (English + Hindi/Hinglish + Devanagari)
        word_number_check = detect_word_numbers(text)
        reasons << word_number_check if word_number_check

        Result.new(
          violates_policy?: reasons.any?,
          reasons: reasons,
          metadata: { checked_length: text.length }
        )
      end

      private

      # Detect standard or obfuscated email patterns
      def detect_email(text)
        # Standard email
        return "standard_email" if text =~ /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/i

        # Spaced email: user @ domain . com
        return "spaced_email" if text =~ /[A-Za-z0-9._%+-]+\s*@\s*[A-Za-z0-9.-]+\s*\.\s*[A-Za-z]{2,}/i

        # Obfuscated tokens: "user [at] gmail [dot] com", "user at the rate gmail dot com"
        at_pattern = /(?:@|\bat\b|\(at\)|\[at\]|\bat\s+the\s+rate\b|\bat_the_rate\b)/i
        dot_pattern = /(?:\.|\bdot\b|\(dot\)|\[dot\])/i
        provider_regex = Regexp.union(EMAIL_PROVIDERS.map { |p| Regexp.new(p.chars.join('\s*'), Regexp::IGNORECASE) })

        if text =~ /#{at_pattern}\s*#{provider_regex}(?:\s*#{dot_pattern}\s*(?:#{TLDS.join('|')}))?/i
          return "obfuscated_email_provider"
        end

        if text =~ /[A-Za-z0-9._%+-]+\s+#{at_pattern}\s+[A-Za-z0-9.-]+\s+#{dot_pattern}\s+(?:#{TLDS.join('|')})/i
          return "obfuscated_email_syntax"
        end

        nil
      end

      # Detect URLs and link shorteners
      def detect_url(text)
        # Direct http/https/www links
        return "web_url" if text =~ %r{\b(?:https?://|www\.)[^\s<>"']+}i

        # Shorteners / direct link apps
        return "short_link" if text =~ /\b(?:bit\.ly|tinyurl\.com|wa\.me|wa\.link|t\.me|linktr\.ee)\/[^\s]+/i

        # Domain with common TLD (e.g. google.com, example.in)
        tld_pattern = Regexp.union(TLDS)
        if text =~ /\b[a-zA-Z0-9-]{3,}\.(?:#{tld_pattern})(?:\/[^\s]*)?\b/i
          return "domain_link"
        end

        nil
      end

      # Detect social media usernames / off-platform redirects
      def detect_social(text)
        normalized = text.downcase

        SOCIAL_PLATFORMS.each do |platform|
          # Match platform name combined with keywords or handles
          if normalized =~ /\b#{platform}\b/i
            # If combined with handle indicator (id, username, @handle, link, number)
            if normalized =~ /\b#{platform}\s*(?:id|handle|username|no|number|pe|par|pr|acc|account|profile)?\s*[:=-]?\s*[@a-z0-9_.]+/i
              return "social_platform_handle (#{platform})"
            end
          end
        end

        # Telegram / Insta / WhatsApp handle patterns: "tg: @username", "insta: john_doe"
        if text =~ /\b(?:tg|tele|insta|ig|snap|wp)\s*[:=]\s*@?[a-zA-Z0-9_.]+/i
          return "messenger_handle_shortcut"
        end

        nil
      end

      # Detect direct 10-15 digit phone numbers
      def detect_direct_phone(text)
        # Indian mobile format with optional +91, 0, or 91 prefix
        return "indian_phone_number" if text =~ /(?:(?:\+?91|0)[\s.-]*)?[6-9]\d{9}\b/

        # Generic 10-15 digits with common phone separators
        return "formatted_phone_number" if text =~ /(?:\+?\d{1,3}[\s.-]*)?(?:\(\d{2,5}\)[\s.-]*)?\d{3,5}[\s.-]*\d{4,5}/ && extract_contiguous_digits(text).length >= 10

        nil
      end

      # Detect obfuscated phone numbers where digits are separated by spaces, dots, dashes, stars, emojis
      def detect_obfuscated_digits(text)
        # Replace Devanagari numerals first
        normalized = text.dup
        DEVANAGARI_DIGITS.each { |dev, dig| normalized.gsub!(dev, dig) }

        # Remove common currency symbols and common non-contact units so prices like "$ 500" or "Rs. 500" don't trigger
        cleaned = normalized.gsub(/(?:rs\.?|inr|usd|\$|€|£|₹|\bkg\b|\bmin\b|\bmins\b|\bkm\b)\s*\d+/i, "")

        # Look for sequences of separated single digits: e.g. "9 8 7 6 5 4 3 2 1 0" or "9.8.7.6.5.4.3.2.1.0" or "9*8*7*6*5*4"
        # Match 7 or more single digits separated by 1-3 non-alphanumeric noise characters
        separated_digits_regex = %r{(?:\b\d[\s\-_.*,/\\|~]{1,4}){6,}\d\b}
        return "separated_digits_sequence" if cleaned =~ separated_digits_regex

        # Check total consecutive digits when stripping noise
        # Only if there's a strong sequence of 10 digits or 7-9 digits combined with a trigger keyword
        has_trigger = CONTACT_TRIGGERS.any? { |trig| text =~ /#{trig}/i }

        # Extract digit groups
        digit_runs = cleaned.scan(/\d+/).join
        if digit_runs.length >= 10 && looks_like_phone_sequence?(digit_runs)
          # Ensure it wasn't just multiple independent normal numbers by checking closeness of digits
          if cleaned =~ /(?:\d[^\w\s]*\s*){8,}\d/
            return "hidden_phone_digits"
          end
        elsif has_trigger && digit_runs.length >= 7
          return "triggered_phone_sequence"
        end

        nil
      end

      # Detect numbers written in words (English + Hindi + Hinglish)
      def detect_word_numbers(text)
        # Pre-process text: lowercase and replace Devanagari words
        normalized = text.downcase
        DEVANAGARI_WORDS.each { |dev, dig| normalized.gsub!(dev, " #{dig} ") }
        DEVANAGARI_DIGITS.each { |dev, dig| normalized.gsub!(dev, " #{dig} ") }

        # Handle multiplier phrases like "double nine" -> "nine nine", "triple eight" -> "eight eight eight"
        normalized = expand_multipliers(normalized)

        # Tokenize words
        tokens = normalized.scan(/[a-z0-9]+/)
        extracted_digits = []
        consecutive_word_digits = 0
        max_consecutive_word_digits = 0

        tokens.each do |token|
          if token =~ /^\d+$/
            # Actual digit token
            token.each_char { |c| extracted_digits << c }
            consecutive_word_digits += token.length
            max_consecutive_word_digits = [ max_consecutive_word_digits, consecutive_word_digits ].max
          elsif (digit = WORD_TO_DIGIT[token])
            # Word number token
            extracted_digits << digit
            consecutive_word_digits += 1
            max_consecutive_word_digits = [ max_consecutive_word_digits, consecutive_word_digits ].max
          else
            # Reset streak if non-number word encountered (allow 1 skip word for noise like "and", "ka", "mera")
            unless %w[and ka mera apna my no number].include?(token)
              consecutive_word_digits = 0
            end
          end
        end

        # If 7 or more consecutive number-words are used, it's definitely a contact number
        if max_consecutive_word_digits >= 7
          return "word_number_sequence (#{max_consecutive_word_digits} digits)"
        end

        # If combined with contact trigger words and at least 6 digits in words
        has_trigger = CONTACT_TRIGGERS.any? { |trig| text =~ /#{trig}/i }
        if has_trigger && max_consecutive_word_digits >= 5
          return "word_number_triggered (#{max_consecutive_word_digits} digits)"
        end

        nil
      end

      # Helper to extract contiguous digits
      def extract_contiguous_digits(text)
        text.scan(/\d/).join
      end

      # Check if sequence looks like valid phone number (not all same digit, reasonable length)
      def looks_like_phone_sequence?(digit_str)
        # Avoid repeated single digit like "0000000000" or "1111111111"
        return false if digit_str =~ /^(\d)\1+$/

        digit_str.length.between?(10, 15)
      end

      # Expand multiplier words like "double 9", "triple eight", "do baar aath"
      def expand_multipliers(text)
        expanded = text.dup
        expanded.gsub!(/\b(?:double|two\s*times|do\s*baar)\s+([a-z0-9]+)/i) do
          word = ::Regexp.last_match(1)
          WORD_TO_DIGIT.key?(word) || word =~ /^\d$/ ? "#{word} #{word}" : "#{word}"
        end
        expanded.gsub!(/\b(?:triple|three\s*times|teen\s*baar)\s+([a-z0-9]+)/i) do
          word = ::Regexp.last_match(1)
          WORD_TO_DIGIT.key?(word) || word =~ /^\d$/ ? "#{word} #{word} #{word}" : "#{word}"
        end
        expanded
      end
    end
  end
end
