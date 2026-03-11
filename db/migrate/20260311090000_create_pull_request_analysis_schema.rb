class CreatePullRequestAnalysisSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.string :owner, null: false
      t.string :name, null: false
      t.string :full_name, null: false
      t.string :default_branch
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :repositories, :full_name, unique: true

    create_table :github_users do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :name
      t.string :avatar_url
      t.string :profile_url
      t.timestamps
    end
    add_index :github_users, :github_id, unique: true
    add_index :github_users, :login

    create_table :pull_requests do |t|
      t.references :repository, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :github_users }
      t.bigint :github_id, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.string :state, null: false
      t.boolean :draft, null: false, default: false
      t.boolean :merged, null: false, default: false
      t.string :pull_request_url, null: false
      t.string :base_branch
      t.string :head_branch
      t.integer :commits_count, null: false, default: 0
      t.integer :additions, null: false, default: 0
      t.integer :deletions, null: false, default: 0
      t.integer :changed_files, null: false, default: 0
      t.datetime :github_created_at, null: false
      t.datetime :ready_for_review_at
      t.datetime :merged_at
      t.datetime :closed_at
      t.datetime :first_reviewed_at
      t.references :first_reviewer, foreign_key: { to_table: :github_users }
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :pull_requests, [ :repository_id, :number ], unique: true
    add_index :pull_requests, :github_id, unique: true
    add_index :pull_requests, :github_created_at
    add_index :pull_requests, :ready_for_review_at
    add_index :pull_requests, :merged_at

    create_table :pull_request_reviews do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :github_users }
      t.bigint :github_id, null: false
      t.string :state, null: false
      t.datetime :submitted_at, null: false
      t.text :body
      t.string :commit_id
      t.timestamps
    end
    add_index :pull_request_reviews, :github_id, unique: true
    add_index :pull_request_reviews, [ :pull_request_id, :submitted_at ]

    create_table :pull_request_events do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :github_users }
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.json :payload, null: false, default: {}
      t.timestamps
    end
    add_index :pull_request_events, [ :pull_request_id, :occurred_at ]
    add_index :pull_request_events, :kind
  end
end
