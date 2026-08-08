# frozen_string_literal: true

class CreatePageFeedbackExportItems < ActiveRecord::Migration[8.0]
  def change
    create_table :page_feedback_export_items do |t|
      t.references :export, null: false, foreign_key: { to_table: :page_feedback_exports }
      t.references :comment, null: false, foreign_key: { to_table: :page_feedback_comments }
      t.string :comment_fingerprint, null: false
      t.integer :position, null: false
      t.timestamps
    end

    add_index :page_feedback_export_items, %i[export_id comment_id], unique: true
    add_index :page_feedback_export_items, %i[comment_id comment_fingerprint]
  end
end
