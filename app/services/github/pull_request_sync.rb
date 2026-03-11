module Github
  class PullRequestSync
    def initialize(repository:, token: nil)
      @repository = repository
      @client = Client.new(token: TokenResolver.resolve(token))
    end

    def call(numbers: nil, author: nil, from: nil, to: nil)
      refresh_repository_metadata!

      pull_request_numbers = Array(numbers).presence || discover_numbers(author:, from:, to:)
      yield(total_count: pull_request_numbers.size, processed_count: 0, current_pull_request_number: nil) if block_given?

      pull_request_numbers.each_with_index do |number, index|
        yield(total_count: pull_request_numbers.size, processed_count: index, current_pull_request_number: number) if block_given?
        sync_pull_request!(number)
        yield(total_count: pull_request_numbers.size, processed_count: index + 1, current_pull_request_number: number) if block_given?
      end

      repository.update!(last_synced_at: Time.current)
      pull_request_numbers
    end

    private

    attr_reader :repository, :client

    def discover_numbers(author:, from:, to:)
      return client.list_pull_request_numbers(repository.full_name) if author.blank? && from.blank? && to.blank?

      client.search_pull_request_numbers(
        full_name: repository.full_name,
        author: author,
        from: from&.to_date&.iso8601,
        to: to&.to_date&.iso8601
      )
    end

    def refresh_repository_metadata!
      payload = client.repository(repository.full_name)
      repository.update!(default_branch: payload["default_branch"])
    end

    def sync_pull_request!(number)
      payload = client.pull_request(repository.full_name, number)
      reviews_payload = client.pull_request_reviews(repository.full_name, number)
      commits_payload = client.pull_request_commits(repository.full_name, number)
      timeline_payload = client.issue_timeline(repository.full_name, number)

      PullRequest.transaction do
        author = upsert_user(payload.fetch("user"))
        pr = repository.pull_requests.find_or_initialize_by(number:)
        ready_for_review_at = ready_for_review_at_for(payload, timeline_payload)
        ordered_reviews = reviews_payload
          .reject { |review| review["submitted_at"].blank? || review["state"].blank? }
          .sort_by { |review| Time.zone.parse(review.fetch("submitted_at")) }
        first_review = ordered_reviews.first
        first_reviewer = first_review ? upsert_user(first_review.fetch("user")) : nil

        pr.assign_attributes(
          author:,
          github_id: payload.fetch("id"),
          title: payload.fetch("title"),
          state: payload.fetch("state"),
          draft: payload.fetch("draft"),
          merged: payload.fetch("merged"),
          pull_request_url: payload.fetch("html_url"),
          base_branch: payload.dig("base", "ref"),
          head_branch: payload.dig("head", "ref"),
          commits_count: payload.fetch("commits"),
          additions: payload.fetch("additions"),
          deletions: payload.fetch("deletions"),
          changed_files: payload.fetch("changed_files"),
          github_created_at: parse_time(payload.fetch("created_at")),
          ready_for_review_at:,
          merged_at: parse_time(payload["merged_at"]),
          closed_at: parse_time(payload["closed_at"]),
          first_reviewed_at: parse_time(first_review&.[]("submitted_at")),
          first_reviewer:,
          last_synced_at: Time.current
        )
        pr.save!

        replace_reviews!(pr, ordered_reviews)
        replace_events!(pr, payload:, reviews_payload: ordered_reviews, commits_payload:, timeline_payload:)
      end
    end

    def replace_reviews!(pull_request, ordered_reviews)
      pull_request.reviews.delete_all
      ordered_reviews.each do |review_payload|
        pull_request.reviews.create!(
          reviewer: upsert_user(review_payload.fetch("user")),
          github_id: review_payload.fetch("id"),
          state: review_payload.fetch("state"),
          submitted_at: parse_time(review_payload.fetch("submitted_at")),
          body: review_payload["body"],
          commit_id: review_payload["commit_id"]
        )
      end
    end

    def replace_events!(pull_request, payload:, reviews_payload:, commits_payload:, timeline_payload:)
      pull_request.events.delete_all
      pull_request.events.create!(
        actor: pull_request.author,
        kind: "created",
        occurred_at: parse_time(payload.fetch("created_at")),
        payload: { title: pull_request.title }
      )

      ready_for_review_at = ready_for_review_at_for(payload, timeline_payload)
      if ready_for_review_at && ready_for_review_at != pull_request.github_created_at
        pull_request.events.create!(
          actor: pull_request.author,
          kind: "ready_for_review",
          occurred_at: ready_for_review_at,
          payload: {}
        )
      end

      reviews_payload.each do |review_payload|
        pull_request.events.create!(
          actor: upsert_user(review_payload.fetch("user")),
          kind: "review",
          occurred_at: parse_time(review_payload.fetch("submitted_at")),
          payload: { state: review_payload.fetch("state"), body: review_payload["body"] }
        )
      end

      commits_payload.each do |commit_payload|
        actor = commit_payload["author"] ? upsert_user(commit_payload.fetch("author")) : nil
        committed_at = commit_payload.dig("commit", "author", "date") || commit_payload.dig("commit", "committer", "date")
        next if committed_at.blank?

        pull_request.events.create!(
          actor:,
          kind: "commit_pushed",
          occurred_at: parse_time(committed_at),
          payload: {
            sha: commit_payload["sha"],
            message: commit_payload.dig("commit", "message")&.lines&.first&.to_s&.strip
          }
        )
      end

      if pull_request.merged_at.present?
        pull_request.events.create!(
          actor: actor_from_timeline(timeline_payload, "merged"),
          kind: "merged",
          occurred_at: pull_request.merged_at,
          payload: {}
        )
      elsif pull_request.closed_at.present?
        pull_request.events.create!(
          actor: actor_from_timeline(timeline_payload, "closed"),
          kind: "closed",
          occurred_at: pull_request.closed_at,
          payload: {}
        )
      end
    end

    def actor_from_timeline(timeline_payload, event_name)
      event = timeline_payload.find { |item| item["event"] == event_name && item["actor"].present? }
      return unless event

      upsert_user(event.fetch("actor"))
    end

    def ready_for_review_at_for(payload, timeline_payload)
      ready_event = timeline_payload.find { |item| item["event"] == "ready_for_review" }
      return parse_time(ready_event["created_at"]) if ready_event.present?
      return parse_time(payload["created_at"]) unless payload.fetch("draft")

      nil
    end

    def upsert_user(payload)
      GithubUser.find_or_initialize_by(github_id: payload.fetch("id")).tap do |user|
        user.login = payload.fetch("login")
        user.name = payload["name"]
        user.avatar_url = payload["avatar_url"]
        user.profile_url = payload["html_url"]
        user.save!
      end
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value)
    end
  end
end
