# frozen_string_literal: true

class AddLabelToPageFeedbackExports < ActiveRecord::Migration[8.0]
  def change
    add_column :page_feedback_exports, :label, :string
  end
end
