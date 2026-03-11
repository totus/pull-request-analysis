class PullRequestEvent < ApplicationRecord
  belongs_to :pull_request
  belongs_to :actor, class_name: "GithubUser", optional: true

  validates :kind, :occurred_at, presence: true

  scope :timeline, -> { order(:occurred_at) }

  def label
    return "Review: #{payload["state"] || "COMMENTED"}" if kind == "review"
    return "Commit pushed" if kind == "commit_pushed"

    kind.humanize
  end
end
