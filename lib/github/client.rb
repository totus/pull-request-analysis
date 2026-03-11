require "json"
require "net/http"
require "uri"

module Github
  class Client
    API_BASE = "https://api.github.com".freeze

    def initialize(token:)
      @token = token
    end

    def repository(full_name)
      get_json("/repos/#{full_name}")
    end

    def list_pull_request_numbers(full_name)
      get_paginated("/repos/#{full_name}/pulls", params: { state: "all", sort: "created", direction: "desc", per_page: 100 })
        .map { |payload| payload.fetch("number") }
    end

    def search_pull_request_numbers(full_name:, author: nil, from: nil, to: nil)
      query = [ "repo:#{full_name}", "is:pr" ]
      query << "author:#{author}" if author.present?
      if from.present? || to.present?
        query << "created:#{from || "*"}..#{to || "*"}"
      end

      get_paginated("/search/issues", params: { q: query.join(" "), sort: "created", order: "desc", per_page: 100 }, items_key: "items")
        .map { |payload| payload.fetch("number") }
        .uniq
    end

    def pull_request(full_name, number)
      get_json("/repos/#{full_name}/pulls/#{number}")
    end

    def pull_request_reviews(full_name, number)
      get_paginated("/repos/#{full_name}/pulls/#{number}/reviews", params: { per_page: 100 })
    end

    def pull_request_commits(full_name, number)
      get_paginated("/repos/#{full_name}/pulls/#{number}/commits", params: { per_page: 100 })
    end

    def issue_timeline(full_name, number)
      get_paginated("/repos/#{full_name}/issues/#{number}/timeline", params: { per_page: 100 })
    end

    private

    attr_reader :token

    def get_paginated(path, params: {}, items_key: nil)
      records = []
      next_url = build_uri(path, params)

      while next_url
        response = request(next_url)
        payload = JSON.parse(response.body)
        batch = items_key ? payload.fetch(items_key) : payload
        records.concat(batch)
        next_url = next_page_url(response["link"])
      end

      records
    end

    def get_json(path, params: {})
      response = request(build_uri(path, params))
      JSON.parse(response.body)
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      response = http.request(request)
      return response if response.is_a?(Net::HTTPSuccess)

      raise Error, "GitHub API request failed (#{response.code}): #{response.body}"
    end

    def build_uri(path, params = {})
      uri = URI.join(API_BASE, path)
      uri.query = URI.encode_www_form(params) if params.present?
      uri
    end

    def next_page_url(link_header)
      return if link_header.blank?

      next_link = link_header.split(",").find { |part| part.include?('rel="next"') }
      return if next_link.blank?

      href = next_link[/<([^>]+)>/, 1]
      href.present? ? URI(href) : nil
    end
  end
end
