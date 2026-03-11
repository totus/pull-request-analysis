class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.integer :total_count, null: false, default: 0
      t.integer :processed_count, null: false, default: 0
      t.integer :current_pull_request_number
      t.json :filters, null: false, default: {}
      t.text :error_message
      t.string :job_id
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :sync_runs, :status
    add_index :sync_runs, :created_at
  end
end
