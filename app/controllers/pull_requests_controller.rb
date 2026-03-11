class PullRequestsController < ApplicationController
  def show
    @pull_request = PullRequest.includes(:repository, :author, :first_reviewer, events: :actor, reviews: :reviewer).find(params[:id])
  end
end
