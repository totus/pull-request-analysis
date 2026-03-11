# Pull Request Analysis

Rails application for analyzing GitHub repositories from pull request data cached in SQLite.

## What it answers

- Time from `ready for review` to the second approving review
- Time from PR creation to merge
- Top reviewers for each PR author
- Top review actions per reviewer with counts
- Per-PR timeline:
  - created
  - ready for review
  - first review and reviewer
  - subsequent reviews and reviewers
  - commit pushes
  - merged or closed without merge

## Stack

- Ruby 3.4
- Rails 8.1
- SQLite
- GitHub REST API with token auth
- Optional `gh auth token` fallback if the GitHub CLI is already logged in via OAuth/device flow

## Setup

```bash
bundle install
bundle exec rails db:prepare
```

## Authentication

The sync layer resolves credentials in this order:

1. Explicit token from the UI refresh form or CLI `--token`
2. `GITHUB_TOKEN`
3. `gh auth token`

If you want the OAuth/device flow, run:

```bash
gh auth login
```

## Run the web UI

```bash
bin/rails server
```

Open [http://localhost:3000](http://localhost:3000), add `owner/repo`, and optionally constrain the initial sync by date range.

The repository page gives:

- cached metrics and PR table
- author and reviewer aggregates
- forced refresh by PR numbers, author, date range, or date range alone
- per-PR timeline pages

## Run the CLI

```bash
bin/pr_analysis sync rails/rails --from=2026-01-01 --to=2026-03-01
bin/pr_analysis summary rails/rails
bin/pr_analysis pr rails/rails 54321
```

Useful flags:

- `--token=...`
- `--author=octocat`
- `--from=YYYY-MM-DD`
- `--to=YYYY-MM-DD`
- `--numbers=123,124,125`

## Refresh behavior

The UI and CLI read from SQLite by default. Data is only re-fetched when you explicitly run a sync or refresh operation.

## Verification

Validated locally with:

```bash
bundle exec rails db:prepare
bundle exec rails routes
bin/pr_analysis help
bundle exec rubocop --cache-root tmp/rubocop-cache
```
