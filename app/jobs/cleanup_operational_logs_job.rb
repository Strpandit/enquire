# frozen_string_literal: true

class CleanupOperationalLogsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 500

  def perform
    clean_old_failed_jobs
    clean_old_activity_logs
    clean_old_read_notifications
  end

  private

  # Clean up failed job errors older than 14 days
  def clean_old_failed_jobs
    return unless defined?(SolidQueue::FailedExecution)

    loop do
      old_failed_job_ids = SolidQueue::FailedExecution
                           .where("created_at < ?", 14.days.ago)
                           .limit(BATCH_SIZE)
                           .pluck(:job_id)

      break if old_failed_job_ids.empty?

      # Cascade delete from solid_queue_jobs removes both the job and failed_execution record
      SolidQueue::Job.where(id: old_failed_job_ids).delete_all
      sleep 0.1
    end
  rescue StandardError => e
    Rails.logger.error("[CleanupOperationalLogsJob] clean_old_failed_jobs error: #{e.message}")
  end

  # Clean up audit activity logs older than 90 days
  def clean_old_activity_logs
    return unless defined?(ActivityLog)

    ActivityLog.where("created_at < ?", 90.days.ago).in_batches(of: BATCH_SIZE) do |batch|
      batch.delete_all
      sleep 0.1
    end
  rescue StandardError => e
    Rails.logger.error("[CleanupOperationalLogsJob] clean_old_activity_logs error: #{e.message}")
  end

  # Clean up notifications that have been read and are older than 60 days
  def clean_old_read_notifications
    return unless defined?(Notification)

    Notification.where.not(read_at: nil)
                .where("read_at < ?", 60.days.ago)
                .in_batches(of: BATCH_SIZE) do |batch|
      batch.delete_all
      sleep 0.1
    end
  rescue StandardError => e
    Rails.logger.error("[CleanupOperationalLogsJob] clean_old_read_notifications error: #{e.message}")
  end
end
