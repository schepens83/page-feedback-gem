# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::ExportItem, type: :model do
  it "belongs to one export and one comment revision" do
    export_item = create(:page_feedback_export_item)

    expect(export_item.export).to be_a(PageFeedback::Export)
    expect(export_item.comment).to be_a(PageFeedback::Comment)
  end

  it "rejects duplicate membership and negative positions" do
    existing_item = create(:page_feedback_export_item, position: 0)
    duplicate_item = build(
      :page_feedback_export_item,
      export: existing_item.export,
      comment: existing_item.comment,
      position: -1
    )

    expect(duplicate_item).not_to be_valid
    expect(duplicate_item.errors).to include(:comment_id, :position)
  end

  it "prevents changing or deleting persisted membership" do
    export_item = create(:page_feedback_export_item)

    expect { export_item.update!(position: 99) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { export_item.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "prevents deleting a comment with export history" do
    export_item = create(:page_feedback_export_item)

    expect(export_item.comment.destroy).to be(false)
    expect(export_item.comment.errors[:base]).not_to be_empty
  end
end
