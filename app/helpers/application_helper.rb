module ApplicationHelper
  STATUS_OPTIONS = %w[open draft merged closed].freeze

  def format_duration(seconds)
    return "n/a" if seconds.blank?

    total_minutes = (seconds / 60).round
    days, remainder = total_minutes.divmod(24 * 60)
    hours, minutes = remainder.divmod(60)

    parts = []
    parts << "#{days}d" if days.positive?
    parts << "#{hours}h" if hours.positive?
    parts << "#{minutes}m" if minutes.positive? || parts.empty?
    parts.join(" ")
  end

  def pull_request_state_badge(pull_request)
    pull_request.computed_status
  end

  def sortable_repository_header(repository, label, key)
    next_direction = params[:sort] == key && params[:direction] != "asc" ? "asc" : "desc"
    indicator = params[:sort] == key ? (params[:direction] == "asc" ? "↑" : "↓") : "↕"
    link_to "#{label} #{indicator}", repository_path(repository, request.query_parameters.merge(sort: key, direction: next_direction))
  end

  def sync_run_status_class(sync_run)
    "sync-status sync-status-#{sync_run.status}"
  end
end
