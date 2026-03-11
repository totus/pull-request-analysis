class SyncRunsController < ApplicationController
  def show
    sync_run = SyncRun.find(params[:id])

    render json: {
      id: sync_run.id,
      status: sync_run.status,
      total_count: sync_run.total_count,
      processed_count: sync_run.processed_count,
      current_pull_request_number: sync_run.current_pull_request_number,
      progress_percentage: sync_run.progress_percentage,
      error_message: sync_run.error_message,
      finished_at: sync_run.finished_at,
      active: sync_run.active?
    }
  end
end
