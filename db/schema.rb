# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_11_101500) do
  create_table "github_users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "name"
    t.string "profile_url"
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_github_users_on_github_id", unique: true
    t.index ["login"], name: "index_github_users_on_login"
  end

  create_table "pull_request_events", force: :cascade do |t|
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "occurred_at", null: false
    t.json "payload", default: {}, null: false
    t.integer "pull_request_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_pull_request_events_on_actor_id"
    t.index ["kind"], name: "index_pull_request_events_on_kind"
    t.index ["pull_request_id", "occurred_at"], name: "index_pull_request_events_on_pull_request_id_and_occurred_at"
    t.index ["pull_request_id"], name: "index_pull_request_events_on_pull_request_id"
  end

  create_table "pull_request_reviews", force: :cascade do |t|
    t.text "body"
    t.string "commit_id"
    t.datetime "created_at", null: false
    t.bigint "github_id", null: false
    t.integer "pull_request_id", null: false
    t.integer "reviewer_id", null: false
    t.string "state", null: false
    t.datetime "submitted_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_pull_request_reviews_on_github_id", unique: true
    t.index ["pull_request_id", "submitted_at"], name: "index_pull_request_reviews_on_pull_request_id_and_submitted_at"
    t.index ["pull_request_id"], name: "index_pull_request_reviews_on_pull_request_id"
    t.index ["reviewer_id"], name: "index_pull_request_reviews_on_reviewer_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "additions", default: 0, null: false
    t.integer "author_id", null: false
    t.string "base_branch"
    t.integer "changed_files", default: 0, null: false
    t.datetime "closed_at"
    t.integer "commits_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "deletions", default: 0, null: false
    t.boolean "draft", default: false, null: false
    t.datetime "first_reviewed_at"
    t.integer "first_reviewer_id"
    t.datetime "github_created_at", null: false
    t.bigint "github_id", null: false
    t.string "head_branch"
    t.datetime "last_synced_at"
    t.boolean "merged", default: false, null: false
    t.datetime "merged_at"
    t.integer "number", null: false
    t.string "pull_request_url", null: false
    t.datetime "ready_for_review_at"
    t.integer "repository_id", null: false
    t.string "state", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_pull_requests_on_author_id"
    t.index ["first_reviewer_id"], name: "index_pull_requests_on_first_reviewer_id"
    t.index ["github_created_at"], name: "index_pull_requests_on_github_created_at"
    t.index ["github_id"], name: "index_pull_requests_on_github_id", unique: true
    t.index ["merged_at"], name: "index_pull_requests_on_merged_at"
    t.index ["ready_for_review_at"], name: "index_pull_requests_on_ready_for_review_at"
    t.index ["repository_id", "number"], name: "index_pull_requests_on_repository_id_and_number", unique: true
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_branch"
    t.string "full_name", null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "owner", null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_repositories_on_full_name", unique: true
  end

  create_table "sync_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_pull_request_number"
    t.text "error_message"
    t.json "filters", default: {}, null: false
    t.datetime "finished_at"
    t.string "job_id"
    t.integer "processed_count", default: 0, null: false
    t.integer "repository_id", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sync_runs_on_created_at"
    t.index ["repository_id"], name: "index_sync_runs_on_repository_id"
    t.index ["status"], name: "index_sync_runs_on_status"
  end

  add_foreign_key "pull_request_events", "github_users", column: "actor_id"
  add_foreign_key "pull_request_events", "pull_requests"
  add_foreign_key "pull_request_reviews", "github_users", column: "reviewer_id"
  add_foreign_key "pull_request_reviews", "pull_requests"
  add_foreign_key "pull_requests", "github_users", column: "author_id"
  add_foreign_key "pull_requests", "github_users", column: "first_reviewer_id"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "sync_runs", "repositories"
end
