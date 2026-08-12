ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "App Monitoring Dashboard"

  content title: "Real-time App Monitoring & Performance Dashboard" do
    div class: "blank_slate_container" do
      h2 "System Overview & Device Analytics"
    end

    # Key Performance Indicator (KPI) Metric Cards
    columns do
      column do
        panel "Active Devices Today" do
          h1 Device.active_today.count, style: "color: #2563eb; font-size: 2.2em; font-weight: bold;"
          para "Total registered: #{Device.count}"
        end
      end

      column do
        panel "Users Active Today" do
          active_user_ids = ActivityLog.where("created_at >= ?", Time.current.beginning_of_day).pluck(:account_id).compact.uniq.count
          h1 active_user_ids, style: "color: #16a34a; font-size: 2.2em; font-weight: bold;"
          para "Total Accounts: #{Account.count}"
        end
      end

      column do
        panel "Calls & Video Today" do
          calls_count = CallHistory.where("created_at >= ?", Time.current.beginning_of_day).count
          h1 calls_count, style: "color: #d97706; font-size: 2.2em; font-weight: bold;"
          para "Total Calls History: #{CallHistory.count}"
        end
      end

      column do
        panel "Payments Today" do
          tx_today = WalletTransaction.where("created_at >= ?", Time.current.beginning_of_day).count
          h1 tx_today, style: "color: #9333ea; font-size: 2.2em; font-weight: bold;"
          para "Total Transactions: #{WalletTransaction.count}"
        end
      end
    end

    # Analytics Panels
    columns do
      column do
        panel "Device Manufacturers & Models" do
          table_for Device.group(:manufacturer, :model).order("count_all desc").limit(8).count do
            column("Manufacturer & Model") { |(mfg, model), _| "#{mfg} #{model}".strip.presence || "Unknown" }
            column("Devices Count") { |_, count| count }
          end
        end
      end

      column do
        panel "Android Versions & API Levels" do
          table_for Device.group(:android_version, :android_api_level).order("count_all desc").limit(8).count do
            column("Android OS / API") { |(ver, api), _| "Android #{ver} (API #{api})".strip }
            column("Count") { |_, count| count }
          end
        end
      end
    end

    columns do
      column do
        panel "App Versions & Build Numbers" do
          table_for Device.group(:app_version, :app_build).order("count_all desc").limit(8).count do
            column("App Version (Build)") { |(ver, build), _| "#{ver} (#{build})" }
            column("Active Users") { |_, count| count }
          end
        end
      end

      column do
        panel "Network Types (Wi-Fi / 4G / 5G)" do
          table_for Device.group(:network_type).order("count_all desc").count do
            column("Network Type") { |net, _| net.presence || "Unknown / Cellular" }
            column("Devices Count") { |_, count| count }
          end
        end
      end
    end

    # Recent Real-time Activity Timeline
    columns do
      column do
        panel "Live Recent Activity Audit Log" do
          table_for ActivityLog.recent.limit(10) do
            column("Time") { |log| time_ago_in_words(log.created_at) + " ago" }
            column("User") { |log| log.account ? link_to(log.account.full_name || log.account.email, admin_account_path(log.account)) : "Guest" }
            column("Event") { |log| status_tag(log.event, class: "status_tag") }
            column("Activity Title") { |log| log.title || log.event.humanize }
            column("Server Observed IP") { |log| log.ip_address.presence || "N/A" }
          end
        end
      end
    end
  end
end
