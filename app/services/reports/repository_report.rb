module Reports
  class RepositoryReport
    SORTS = %w[number author state ready_to_approval created_to_merged first_review created_at].freeze
    DIRECTIONS = %w[asc desc].freeze
    STATUS_OPTIONS = %w[open draft merged closed].freeze

    attr_reader :repository, :from, :to, :sort, :direction

    def initialize(repository:, include_authors: nil, exclude_authors: nil, from: nil, to: nil, included_statuses: nil, excluded_statuses: nil, sort: nil, direction: nil)
      @repository = repository
      @include_authors = parse_list(include_authors)
      @exclude_authors = parse_list(exclude_authors)
      @from = from.presence && Time.zone.parse(from.to_s)
      @to = to.presence && Time.zone.parse(to.to_s).end_of_day
      @included_statuses = parse_statuses(included_statuses)
      @excluded_statuses = parse_statuses(excluded_statuses)
      @sort = SORTS.include?(sort) ? sort : "created_at"
      @direction = DIRECTIONS.include?(direction) ? direction : "desc"
    end

    def pull_requests
      @pull_requests ||= sort_pull_requests(filtered_scope.load)
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

    def filtered_scope
      scope = repository.pull_requests
        .includes(:author, :first_reviewer, reviews: :reviewer)
        .created_between(from, to)
      scope = scope.with_authors(@include_authors) if @include_authors.any?
      scope = scope.without_authors(@exclude_authors) if @exclude_authors.any?
      filter_by_status(scope)
    end

    def filter_by_status(scope)
      included_ids = if @included_statuses.any?
        scope.select { |pull_request| @included_statuses.include?(pull_request.computed_status) }.map(&:id)
      else
        scope.pluck(:id)
      end

      excluded_ids = if @excluded_statuses.any?
        scope.select { |pull_request| @excluded_statuses.include?(pull_request.computed_status) }.map(&:id)
      else
        []
      end

      scope.where(id: included_ids - excluded_ids)
    end

    def sort_pull_requests(records)
      sorted = records.sort_by do |pull_request|
        case sort
        when "number" then pull_request.number
        when "author" then pull_request.author.login
        when "state" then pull_request.computed_status
        when "ready_to_approval" then pull_request.time_to_second_approval || Float::INFINITY
        when "created_to_merged" then pull_request.time_to_merge || Float::INFINITY
        when "first_review" then pull_request.first_reviewed_at&.to_i || Float::INFINITY
        else
          pull_request.github_created_at.to_i
        end
      end

      direction == "desc" ? sorted.reverse : sorted
    end

    def review_counts
      PullRequestReview.joins(:pull_request, :reviewer)
        .where(pull_requests: { id: pull_requests.map(&:id) })
        .group("github_users.id", :state)
        .count
        .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((reviewer_id, state), count), memo|
          memo[reviewer_id][state] += count
        end
    end

    def parse_list(value)
      value.to_s.split(",").map(&:strip).reject(&:blank?).uniq
    end

    def parse_statuses(values)
      Array(values).filter_map do |value|
        normalized = value.to_s
        normalized if STATUS_OPTIONS.include?(normalized)
      end.uniq
    end

    def average_duration(values)
      return if values.empty?

      values.sum / values.length
    end
  end
end
