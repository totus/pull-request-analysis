class PullRequestReview < ApplicationRecord
  belongs_to :pull_request
  belongs_to :reviewer, class_name: "GithubUser"

  validates :github_id, :state, :submitted_at, presence: true
  validates :github_id, uniqueness: true

  def approved?
    state == "APPROVED"
  end
end
