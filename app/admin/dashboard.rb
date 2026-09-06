require "cgi"

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Dashboard"

  dash_styles = <<~CSS
    .pt-dash-head { margin: 4px 0 22px; }
    .pt-dash-head h2 { margin: 0; font-size: 20px; font-weight: 700; letter-spacing: -0.01em; }
    .pt-dash-head p  { margin: 4px 0 0; font-size: 12.5px; color: #6b7280; }

    .pt-kpi-grid {
      display: grid; grid-template-columns: repeat(4, 1fr);
      gap: 16px; margin-bottom: 8px;
    }
    .pt-kpi {
      background: #fff; border: 1px solid #e5e7eb; border-radius: 12px;
      padding: 16px 18px; position: relative; overflow: hidden;
      box-shadow: 0 1px 2px rgba(16,24,40,.04);
    }
    .pt-kpi::before {
      content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 4px;
    }
    .pt-kpi-blue::before   { background: #2563eb; }
    .pt-kpi-green::before  { background: #16a34a; }
    .pt-kpi-amber::before  { background: #d97706; }
    .pt-kpi-purple::before { background: #9333ea; }
    .pt-kpi-label {
      font-size: 11px; font-weight: 600; text-transform: uppercase;
      letter-spacing: .06em; color: #6b7280; margin-bottom: 8px;
    }
    .pt-kpi-value { font-size: 30px; font-weight: 750; line-height: 1; color: #111827; font-variant-numeric: tabular-nums; }
    .pt-kpi-blue   .pt-kpi-value { color: #2563eb; }
    .pt-kpi-green  .pt-kpi-value { color: #16a34a; }
    .pt-kpi-amber  .pt-kpi-value { color: #d97706; }
    .pt-kpi-purple .pt-kpi-value { color: #9333ea; }
    .pt-kpi-sub { margin-top: 8px; font-size: 12px; color: #6b7280; }

    .pt-panel-body { padding: 2px 0; }

    .pt-dist { display: flex; flex-direction: column; gap: 10px; }
    .pt-row {
      display: grid; grid-template-columns: minmax(120px, 34%) 1fr 48px;
      align-items: center; gap: 12px;
    }
    .pt-row-label {
      font-size: 13px; color: #1f2937; white-space: nowrap;
      overflow: hidden; text-overflow: ellipsis;
    }
    .pt-row-track {
      height: 9px; background: #eef1f5; border-radius: 999px; overflow: hidden;
    }
    .pt-row-fill {
      height: 100%; min-width: 3px; border-radius: 999px;
      background: linear-gradient(90deg, #3b82f6, #2563eb);
    }
    .pt-row-value {
      font-size: 13px; font-weight: 650; color: #111827;
      text-align: right; font-variant-numeric: tabular-nums;
    }
    .pt-empty { margin: 6px 2px; font-size: 13px; color: #9ca3af; font-style: italic; }

    .pt-activity table { width: 100%; }
    .pt-activity td { vertical-align: middle; font-size: 13px; }

    @media (max-width: 1100px) { .pt-kpi-grid { grid-template-columns: repeat(2, 1fr); } }
    @media (max-width: 560px)  { .pt-kpi-grid { grid-template-columns: 1fr; } }
  CSS

  # Renders an ordered { key => count } hash as a labelled horizontal bar list.
  distribution = lambda do |data, &label|
    pairs = data.to_a
    next "<p class=\"pt-empty\">No data recorded yet.</p>".html_safe if pairs.empty?

    max = pairs.map { |_k, c| c.to_f }.max
    max = 1.0 if max.nil? || max.zero?

    rows = pairs.map do |key, count|
      name = CGI.escapeHTML(label.call(key).to_s.strip)
      name = "Unknown" if name.empty?
      pct  = (count.to_f / max * 100).round
      <<~ROW
        <div class="pt-row">
          <div class="pt-row-label" title="#{name}">#{name}</div>
          <div class="pt-row-track"><div class="pt-row-fill" style="width:#{pct}%"></div></div>
          <div class="pt-row-value">#{count}</div>
        </div>
      ROW
    end.join

    %(<div class="pt-dist">#{rows}</div>).html_safe
  end

  content title: "App Monitoring Dashboard" do
    text_node "<style>#{dash_styles}</style>".html_safe

    start_of_day = Time.current.beginning_of_day

    div class: "pt-dash-head" do
      h2 "System Overview & Device Analytics"
      para "Updated #{Time.current.strftime('%d %b %Y, %I:%M %p')}"
    end

    # -- KPI cards -------------------------------------------------------------
    kpis = [
      {
        label: "Active Devices Today", accent: "blue",
        value: Device.active_today.count,
        sub: "#{Device.count} devices registered"
      },
      {
        label: "Users Active Today", accent: "green",
        value: ActivityLog.where("created_at >= ?", start_of_day).where.not(account_id: nil).distinct.count(:account_id),
        sub: "#{Account.count} accounts total"
      },
      {
        label: "Calls & Video Today", accent: "amber",
        value: CallHistory.where("created_at >= ?", start_of_day).count,
        sub: "#{CallHistory.count} calls all-time"
      },
      {
        label: "Payments Today", accent: "purple",
        value: WalletTransaction.where("created_at >= ?", start_of_day).count,
        sub: "#{WalletTransaction.count} transactions all-time"
      }
    ]

    cards = kpis.map do |k|
      %(
        <div class="pt-kpi pt-kpi-#{k[:accent]}">
          <div class="pt-kpi-label">#{CGI.escapeHTML(k[:label])}</div>
          <div class="pt-kpi-value">#{k[:value]}</div>
          <div class="pt-kpi-sub">#{CGI.escapeHTML(k[:sub])}</div>
        </div>
      )
    end.join

    text_node %(<div class="pt-kpi-grid">#{cards}</div>).html_safe

    # -- Distribution panels -------------------------------------------------
    columns do
      column do
        panel "Device Manufacturers & Models" do
          div class: "pt-panel-body" do
            text_node distribution.call(
              Device.group(:manufacturer, :model).order("count_all desc").limit(8).count
            ) { |(mfg, model)| "#{mfg} #{model}".strip }
          end
        end
      end

      column do
        panel "Android Versions & API Levels" do
          div class: "pt-panel-body" do
            text_node distribution.call(
              Device.group(:android_version, :android_api_level).order("count_all desc").limit(8).count
            ) { |(ver, api)| ver.present? ? "Android #{ver}  ·  API #{api}" : "" }
          end
        end
      end
    end

    columns do
      column do
        panel "App Versions & Build Numbers" do
          div class: "pt-panel-body" do
            text_node distribution.call(
              Device.group(:app_version, :app_build).order("count_all desc").limit(8).count
            ) { |(ver, build)| ver.present? ? "v#{ver} (build #{build})" : "" }
          end
        end
      end

      column do
        panel "Network Types (Wi-Fi / Cellular)" do
          div class: "pt-panel-body" do
            text_node distribution.call(
              Device.group(:network_type).order("count_all desc").count
            ) { |net| net.present? ? net.to_s.titleize : "" }
          end
        end
      end
    end

    # -- Recent activity ---------------------------------------------------
    columns do
      column do
        panel "Recent Activity" do
          div class: "pt-panel-body pt-activity" do
            table_for ActivityLog.recent.limit(12) do
              column("When") { |log| "#{time_ago_in_words(log.created_at)} ago" }
              column("User") do |log|
                if log.account
                  link_to(log.account.try(:full_name).presence || log.account.email, admin_account_path(log.account))
                else
                  "Guest"
                end
              end
              column("Event")   { |log| status_tag(log.event.to_s.humanize) }
              column("Details")  { |log| log.try(:title).presence || log.event.to_s.humanize }
              column("IP Address") { |log| log.ip_address.presence || "—" }
            end
          end
        end
      end
    end
  end
end
