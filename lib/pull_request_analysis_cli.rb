require "thor"

class PullRequestAnalysisCli < Thor
  class_option :token, type: :string

  desc "sync REPOSITORY", "Fetch pull request data into SQLite"
  option :author, type: :string
  option :from, type: :string
  option :to, type: :string
  option :numbers, type: :string
  def sync(full_name)
    repository = Repository.find_or_create_by!(full_name: full_name.downcase)
    numbers = parse_numbers(options[:numbers])
    synced_numbers = Github::PullRequestSync.new(repository:, token: options[:token]).call(
      numbers:,
      author: options[:author],
      from: options[:from],
      to: options[:to]
    )

    say("Synced #{synced_numbers.size} pull requests for #{repository.full_name}")
  end

  desc "summary REPOSITORY", "Show condensed metrics from cached data"
  option :author, type: :string
  option :from, type: :string
  option :to, type: :string
  def summary(full_name)
    repository = Repository.find_by!(full_name: full_name.downcase)
    report = Reports::RepositoryReport.new(repository:, author_login: options[:author], from: options[:from], to: options[:to])

    say("Repository: #{repository.full_name}")
    say("PRs: #{report.pull_requests.count}")
    say("Ready for review to 2 approvals: #{ApplicationController.helpers.format_duration(report.average_ready_for_review_to_second_approval)}")
    say("Created to merged: #{ApplicationController.helpers.format_duration(report.average_creation_to_merge)}")
    say("")
    say("Top reviewers per author:")
    report.author_top_reviewers.each do |entry|
      reviewer_summary = entry[:reviewers].map { |reviewer| "#{reviewer[:reviewer].login} (#{reviewer[:reviews_count]})" }.join(", ")
      say("- #{entry[:author].login}: #{reviewer_summary.presence || 'none'}")
    end
    say("")
    say("Reviewer actions:")
    report.reviewer_action_breakdown.each do |entry|
      actions = entry[:actions].sort.map { |state, count| "#{state}=#{count}" }.join(", ")
      say("- #{entry[:reviewer].login}: #{actions}")
    end
  end

  desc "pr REPOSITORY NUMBER", "Show a single PR timeline from cached data"
  def pr(full_name, number)
    repository = Repository.find_by!(full_name: full_name.downcase)
    pull_request = repository.pull_requests.includes(:author, events: :actor).find_by!(number: number.to_i)

    say("PR ##{pull_request.number}: #{pull_request.title}")
    say("Author: #{pull_request.author.login}")
    say("Ready for review to 2 approvals: #{ApplicationController.helpers.format_duration(pull_request.time_to_second_approval)}")
    say("Created to merged: #{ApplicationController.helpers.format_duration(pull_request.time_to_merge)}")
    say("")
    pull_request.events.timeline.each do |event|
      actor = event.actor&.login || "system"
      details = event.payload["state"] || event.payload["message"]
      line = "#{event.occurred_at.iso8601} | #{event.label} | #{actor}"
      line = "#{line} | #{details}" if details.present?
      say(line)
    end
  end

  private

  def parse_numbers(value)
    return if value.blank?

    value.split(",").map(&:strip).reject(&:blank?).map(&:to_i)
  end
end
