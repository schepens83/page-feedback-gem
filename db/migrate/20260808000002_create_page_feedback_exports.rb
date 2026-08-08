# frozen_string_literal: true

class CreatePageFeedbackExports < ActiveRecord::Migration[8.0]
  def change
    create_table :page_feedback_exports do |t|
      t.string :format, null: false, default: "markdown"
      t.text :body, null: false
      t.string :body_digest, null: false
      t.string :created_by_type
      t.bigint :created_by_id
      t.timestamps
    end

    add_index :page_feedback_exports, :created_at
    add_index :page_feedback_exports, %i[created_by_type created_by_id]
  end
end
