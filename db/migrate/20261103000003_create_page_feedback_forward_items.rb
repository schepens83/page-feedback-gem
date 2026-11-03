# frozen_string_literal: true

# Which comments one forward carried.
class CreatePageFeedbackForwardItems < ActiveRecord::Migration[8.0]
  def change
    create_table :page_feedback_forward_items do |t|
      t.references :forward, null: false, foreign_key: { to_table: :page_feedback_forwards }
      t.references :comment, null: false, foreign_key: { to_table: :page_feedback_comments }
      t.timestamps
    end

    add_index :page_feedback_forward_items, %i[forward_id comment_id], unique: true
  end
end
