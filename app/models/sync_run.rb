class SyncRun < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :repository

  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[queued running]) }

  def mark_running!
    update!(status: "running", started_at: Time.current, error_message: nil)
  end

  def mark_completed!
    update!(status: "completed", processed_count: total_count, current_pull_request_number: nil, finished_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, current_pull_request_number: nil, finished_at: Time.current)
  end

  def record_progress!(total_count: nil, processed_count: nil, current_pull_request_number: nil)
    update!(
      total_count: total_count || self.total_count,
      processed_count: processed_count || self.processed_count,
      current_pull_request_number:
    )
  end

  def progress_percentage
    return 0 if total_count.zero?

    ((processed_count.to_f / total_count) * 100).round
  end

  def active?
    status.in?(%w[queued running])
  end
end
