class RepositoriesController < ApplicationController
  before_action :set_repository, only: [ :show, :refresh ]

  def index
    @repositories = Repository.alphabetical
  end

  def create
    @repository = Repository.find_or_initialize_by(full_name: repository_params[:full_name].to_s.strip.downcase)
    @repository.save!

    queue_sync!(@repository)
    redirect_to @repository, notice: "Repository created. Initial sync queued."
  rescue ActiveRecord::RecordInvalid => e
    @repositories = Repository.alphabetical
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :index, status: :unprocessable_entity
  rescue Github::Error => e
    redirect_to root_path, alert: e.message
  end

  def show
    @report = Reports::RepositoryReport.new(
      repository: @repository,
      include_authors: params[:include_authors],
      exclude_authors: params[:exclude_authors],
      from: params[:from],
      to: params[:to],
      included_statuses: params[:included_statuses],
      excluded_statuses: params[:excluded_statuses],
      sort: params[:sort],
      direction: params[:direction]
    )
    @sync_runs = @repository.sync_runs.recent_first.limit(5)
    @active_sync_run = @repository.sync_runs.active.recent_first.first
  end

  def refresh
    queue_sync!(@repository)
    redirect_to repository_path(@repository, filter_redirect_params), notice: "Repository refresh queued."
  rescue ActiveRecord::RecordInvalid, Github::Error => e
    redirect_to repository_path(@repository, filter_redirect_params), alert: e.message
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:full_name)
  end

  def queue_sync!(repository)
    sync_run = repository.sync_runs.create!(
      filters: {
        author: sync_params[:author],
        from: sync_params[:from],
        to: sync_params[:to],
        numbers: parsed_numbers
      }.compact_blank
    )
    job = RepositorySyncJob.perform_later(sync_run.id, token: sync_params[:token].presence)
    sync_run.update!(job_id: job.job_id)
  end

  def sync_params
    params.fetch(:sync, {}).permit(:token, :author, :from, :to, :numbers)
  end

  def parsed_numbers
    return if sync_params[:numbers].blank?

    sync_params[:numbers].split(",").map(&:strip).reject(&:blank?).map(&:to_i)
  end

  def filter_redirect_params
    {
      include_authors: params[:include_authors],
      exclude_authors: params[:exclude_authors],
      from: sync_params[:from].presence || params[:from],
      to: sync_params[:to].presence || params[:to],
      included_statuses: Array(params[:included_statuses]).presence,
      excluded_statuses: Array(params[:excluded_statuses]).presence,
      sort: params[:sort],
      direction: params[:direction]
    }.compact
  end
end
