class ProfilesController < ActionController::Base
  PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.previewtax".freeze
  WEBSITE_URL = "https://previewtax.com".freeze

  def assetlinks
    default_shas = [
      "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C",
      "1F:57:32:AE:80:BB:EC:14:38:38:D9:F5:58:52:30:6A:CB:79:12:61:B9:C9:72:A4:52:79:4D:A1:C6:2D:DE:C1"
    ]
    configured_shas = ENV.fetch("ANDROID_SHA256_FINGERPRINTS", "").split(",").map(&:strip).reject(&:blank?)
    fingerprints = (default_shas + configured_shas).uniq

    render json: [
      {
        relation: [ "delegate_permission/common.handle_all_urls" ],
        target: {
          namespace: "android_app",
          package_name: "com.previewtax",
          sha256_cert_fingerprints: fingerprints
        }
      }
    ], status: :ok
  end

  def show
    business_profile = BusinessProfile.find_by!(share_token: params[:share_token], approval_status: :approved)
    redirect_to public_expert_url(business_profile.account.uid, host: request.base_url), allow_other_host: true
  end

  def expert
    business_profile = BusinessProfile.includes(:account).joins(:account).find_by!(
      accounts: { uid: params[:uid] },
      approval_status: :approved
    )

    @expert_uid = business_profile.account.uid
    @expert_name = business_profile.account.full_name.presence || business_profile.business_name
    @deep_link_url = "previewtax://expert/#{@expert_uid}"
    @play_store_url = PLAY_STORE_URL
    @fallback_url = play_store_listed? ? PLAY_STORE_URL : WEBSITE_URL
    @intent_url = "intent://expert/#{@expert_uid}#Intent;scheme=previewtax;package=com.previewtax;" \
                  "S.browser_fallback_url=#{ERB::Util.url_encode(@fallback_url)};end"

    render inline: <<~HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title><%= ERB::Util.html_escape(@expert_name) %> | PreviewTax</title>
          <style>
            body {
              margin: 0;
              font-family: Arial, sans-serif;
              background: #f8fafc;
              color: #0f172a;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              padding: 24px;
            }
            .card {
              max-width: 420px;
              background: #ffffff;
              border-radius: 20px;
              padding: 28px;
              box-shadow: 0 12px 30px rgba(15, 23, 42, 0.08);
              text-align: center;
            }
            h1 {
              margin: 0 0 12px;
              font-size: 24px;
            }
            p {
              margin: 0 0 20px;
              color: #475569;
              line-height: 1.6;
            }
            a.button {
              display: inline-block;
              background: #f97316;
              color: #ffffff;
              text-decoration: none;
              border-radius: 12px;
              padding: 14px 18px;
              font-weight: 700;
            }
          </style>
          <script>
            window.addEventListener("load", function () {
              const deepLink = <%= raw @deep_link_url.to_json %>;
              const intentUrl = <%= raw @intent_url.to_json %>;
              const fallbackUrl = <%= raw @fallback_url.to_json %>;
              const isAndroid = /android/i.test(navigator.userAgent);
              let left = false;

              document.addEventListener("visibilitychange", function () {
                if (document.hidden) left = true;
              });
              window.addEventListener("pagehide", function () { left = true; });

              if (!isAndroid) {
                window.location.replace(fallbackUrl);
                return;
              }

              window.location.href = intentUrl;
              setTimeout(function () {
                if (!left && !document.hidden) {
                  window.location.href = deepLink;
                  setTimeout(function () {
                    if (!left && !document.hidden) window.location.replace(fallbackUrl);
                  }, 1500);
                }
              }, 1500);
            });
          </script>
        </head>
        <body>
          <div class="card">
            <h1>Open in PreviewTax</h1>
            <p>Continue to <%= ERB::Util.html_escape(@expert_name) %>'s expert profile in the PreviewTax app.</p>
            <a class="button" href="<%= @fallback_url %>">Get the app</a>
          </div>
        </body>
      </html>
    HTML
  end

  private

  def play_store_listed?
    Rails.cache.fetch("play_store_listed", expires_in: 1.hour) do
      uri = URI.parse(PLAY_STORE_URL)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri)).code == "200"
      end
    rescue StandardError
      false
    end
  end
end
