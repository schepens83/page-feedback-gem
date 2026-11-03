# frozen_string_literal: true

# One immutable record per forward of comments to another installation.
class CreatePageFeedbackForwards < ActiveRecord::Migration[8.0]
  def change
    create_table :page_feedback_forwards do |t|
      t.string :destination_url, null: false
      t.string :created_by_type
      t.bigint :created_by_id
      t.timestamps
    end

    add_index :page_feedback_forwards, :created_at
    add_index :page_feedback_forwards, %i[created_by_type created_by_id]
  end
end
