module Reports
  class RepositoryReport
    attr_reader :repository, :author_login, :from, :to

    def initialize(repository:, author_login: nil, from: nil, to: nil)
      @repository = repository
      @author_login = author_login.presence
      @from = from.presence && Time.zone.parse(from.to_s)
      @to = to.presence && Time.zone.parse(to.to_s).end_of_day
    end

    def pull_requests
      @pull_requests ||= begin
        scope = repository.pull_requests
          .includes(:author, :first_reviewer, reviews: :reviewer)
          .created_between(from, to)
          .recent_first
        scope = scope.joins(:author).where(github_users: { login: author_login }) if author_login.present?
        scope
      end
    end

    def average_ready_for_review_to_second_approval
      average_duration(pull_requests.filter_map(&:time_to_second_approval))
    end

    def average_creation_to_merge
      average_duration(pull_requests.filter_map(&:time_to_merge))
    end

    def author_top_reviewers(limit: 5)
      pull_requests.group_by(&:author).map do |author, prs|
        review_counts = prs.flat_map(&:reviews)
          .group_by(&:reviewer)
          .map do |reviewer, reviews|
            {
              reviewer:,
              reviews_count: reviews.count,
              pull_requests_count: reviews.map(&:pull_request_id).uniq.count
            }
          end
          .sort_by { |entry| [ -entry[:reviews_count], -entry[:pull_requests_count], entry[:reviewer].login ] }
          .first(limit)

        { author:, reviewers: review_counts }
      end.sort_by { |entry| entry[:author].login }
    end

    def reviewer_action_breakdown
      reviewer_map = GithubUser.where(id: review_counts.keys).index_by(&:id)

      review_counts
        .map do |reviewer_id, states|
          total = states.values.sum
          { reviewer: reviewer_map.fetch(reviewer_id), actions: states, total: total }
        end
        .sort_by { |entry| [ -entry[:total], entry[:reviewer].login ] }
    end

    private

    def review_counts
      PullRequestReview.joins(:pull_request, :reviewer)
        .where(pull_requests: { id: pull_requests.select(:id) })
        .group("github_users.id", :state)
        .count
        .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((reviewer_id, state), count), memo|
          memo[reviewer_id][state] += count
        end
    end

    def average_duration(values)
      return if values.empty?

      values.sum / values.length
    end
  end
end
