class ProfilesController < ActionController::Base
  PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.previewtax".freeze

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
              const deepLink = "<%= @deep_link_url %>";
              const playStoreUrl = "<%= @play_store_url %>";
              const startedAt = Date.now();

              window.location.href = deepLink;

              setTimeout(function () {
                if (Date.now() - startedAt < 1800) {
                  window.location.href = playStoreUrl;
                }
              }, 1400);
            });
          </script>
        </head>
        <body>
          <div class="card">
            <h1>Open in PreviewTax</h1>
            <p>Continue to <%= ERB::Util.html_escape(@expert_name) %>'s expert profile in the PreviewTax app.</p>
            <a class="button" href="<%= @play_store_url %>">Get the app</a>
          </div>
        </body>
      </html>
    HTML
  end
end
