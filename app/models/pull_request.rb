class PullRequest < ApplicationRecord
  belongs_to :repository
  belongs_to :author, class_name: "GithubUser"
  belongs_to :first_reviewer, class_name: "GithubUser", optional: true

  has_many :reviews, -> { order(:submitted_at) }, class_name: "PullRequestReview", dependent: :destroy
  has_many :events, -> { order(:occurred_at) }, class_name: "PullRequestEvent", dependent: :destroy

  validates :github_id, :number, :title, :state, :pull_request_url, :github_created_at, presence: true
  validates :github_id, uniqueness: true

  scope :recent_first, -> { order(github_created_at: :desc) }
  scope :with_authors, ->(logins) { joins(:author).where(github_users: { login: logins }) }
  scope :without_authors, ->(logins) { joins(:author).where.not(github_users: { login: logins }) }
  scope :created_between, lambda { |from_time, to_time|
    scope = all
    scope = scope.where("github_created_at >= ?", from_time) if from_time.present?
    scope = scope.where("github_created_at <= ?", to_time) if to_time.present?
    scope
  }

  def second_approval_at
    reviews.select(&:approved?).sort_by(&:submitted_at).second&.submitted_at
  end

  def computed_status
    return "merged" if merged?
    return "closed" if closed_at.present?
    return "draft" if draft?

    "open"
  end

  def time_to_second_approval
    return unless ready_for_review_at && second_approval_at

    second_approval_at - ready_for_review_at
  end

  def time_to_merge
    return unless merged_at

    merged_at - github_created_at
  end
end
