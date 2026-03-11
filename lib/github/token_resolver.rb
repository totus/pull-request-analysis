require "open3"

module Github
  class TokenResolver
    def self.resolve(explicit_token = nil)
      return explicit_token if explicit_token.present?
      return ENV["GITHUB_TOKEN"] if ENV["GITHUB_TOKEN"].present?

      stdout, status = Open3.capture2("gh", "auth", "token")
      return stdout.strip if status.success? && stdout.present?

      raise Error, "GitHub token missing. Provide one explicitly, set GITHUB_TOKEN, or run `gh auth login`."
    rescue Errno::ENOENT
      raise Error, "GitHub CLI is not installed. Provide GITHUB_TOKEN or pass --token."
    end
  end
end
