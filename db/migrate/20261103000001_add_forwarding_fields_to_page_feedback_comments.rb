# frozen_string_literal: true

require "securerandom"

# Gives every comment a stable identity across installations, so a forwarded
# comment can be imported once, and records where an imported comment came from.
class AddForwardingFieldsToPageFeedbackComments < ActiveRecord::Migration[8.0]
  # Minimal model so the backfill does not depend on the engine's current code.
  class MigrationComment < ActiveRecord::Base
    self.table_name = "page_feedback_comments"
  end

  def up
    add_column :page_feedback_comments, :uuid, :string
    add_column :page_feedback_comments, :origin, :string
    add_column :page_feedback_comments, :submitter_label, :string

    MigrationComment.reset_column_information
    MigrationComment.where(uuid: nil).find_each do |comment|
      comment.update!(uuid: SecureRandom.uuid)
    end

    change_column_null :page_feedback_comments, :uuid, false
    add_index :page_feedback_comments, :uuid, unique: true
  end

  def down
    remove_index :page_feedback_comments, :uuid
    remove_column :page_feedback_comments, :submitter_label
    remove_column :page_feedback_comments, :origin
    remove_column :page_feedback_comments, :uuid
  end
end
