# frozen_string_literal: true

class CreatePageFeedbackComments < ActiveRecord::Migration[8.0]
  def change
    create_table :page_feedback_comments do |t|
      t.string :status, null: false, default: "pending"
      t.string :category, null: false, default: "idea"
      t.text :comment_text, null: false
      t.text :refined_text
      t.text :reviewer_notes
      t.string :page_path, null: false
      t.string :page_title
      t.string :controller_action
      t.text :css_selector
      t.text :element_html
      t.json :context, null: false, default: {}
      t.string :submitter_type
      t.bigint :submitter_id
      t.string :reviewed_by_type
      t.bigint :reviewed_by_id
      t.datetime :approved_at
      t.datetime :rejected_at
      t.timestamps
    end

    add_index :page_feedback_comments, :status
    add_index :page_feedback_comments, :category
    add_index :page_feedback_comments, :page_path
    add_index :page_feedback_comments, :created_at
    add_index :page_feedback_comments, %i[submitter_type submitter_id]
    add_index :page_feedback_comments, %i[reviewed_by_type reviewed_by_id]
  end
end
