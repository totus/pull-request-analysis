class RepositorySyncJob < ApplicationJob
  queue_as :default

  def perform(sync_run_id, token: nil)
    sync_run = SyncRun.find(sync_run_id)
    sync_run.mark_running!

    Github::PullRequestSync.new(repository: sync_run.repository, token: token).call(
      numbers: parsed_numbers(sync_run),
      author: sync_run.filters["author"],
      from: sync_run.filters["from"],
      to: sync_run.filters["to"]
    ) do |progress|
      sync_run.record_progress!(
        total_count: progress[:total_count],
        processed_count: progress[:processed_count],
        current_pull_request_number: progress[:current_pull_request_number]
      )
    end

    sync_run.mark_completed!
  rescue StandardError => e
    sync_run&.mark_failed!(e.message)
    raise
  end

  private

  def parsed_numbers(sync_run)
    Array(sync_run.filters["numbers"]).presence
  end
end
