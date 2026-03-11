module ApplicationHelper
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
    if pull_request.merged?
      "merged"
    elsif pull_request.closed_at.present?
      "closed"
    elsif pull_request.draft?
      "draft"
    else
      pull_request.state
    end
  end
end
