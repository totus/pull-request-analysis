class RepositoriesController < ApplicationController
  before_action :set_repository, only: [ :show, :refresh ]

  def index
    @repositories = Repository.alphabetical
  end

  def create
    @repository = Repository.find_or_initialize_by(full_name: repository_params[:full_name].to_s.strip.downcase)
    @repository.save!

    sync_repository!(@repository)
    redirect_to @repository, notice: "Repository synced."
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
      author_login: params[:author],
      from: params[:from],
      to: params[:to]
    )
  end

  def refresh
    sync_repository!(@repository)
    redirect_to repository_path(@repository, filter_redirect_params), notice: "Repository refreshed."
  rescue Github::Error => e
    redirect_to repository_path(@repository, filter_redirect_params), alert: e.message
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:full_name)
  end

  def sync_repository!(repository)
    Github::PullRequestSync.new(repository:, token: sync_params[:token]).call(
      numbers: parsed_numbers,
      author: sync_params[:author],
      from: sync_params[:from],
      to: sync_params[:to]
    )
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
      author: sync_params[:author].presence || params[:author],
      from: sync_params[:from].presence || params[:from],
      to: sync_params[:to].presence || params[:to]
    }.compact
  end
end
