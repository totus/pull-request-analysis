class GithubUser < ApplicationRecord
  has_many :authored_pull_requests, class_name: "PullRequest", foreign_key: :author_id
  has_many :performed_reviews, class_name: "PullRequestReview", foreign_key: :reviewer_id
  has_many :performed_events, class_name: "PullRequestEvent", foreign_key: :actor_id

  validates :github_id, :login, presence: true
  validates :github_id, uniqueness: true
end
