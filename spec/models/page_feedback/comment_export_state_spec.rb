# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Comment, "#export_state", type: :model do
  after { PageFeedback.reset_configuration! }

  let(:meaningful_changes) do
    {
      category: "bug",
      refined_text: "Refined feedback",
      reviewer_notes: "Preserve keyboard access",
      page_path: "/projects/43",
      page_title: "Project 43",
      controller_action: "projects#edit",
      css_selector: ".project-editor",
      element_html: "<main>Editor</main>"
    }
  end

  describe "fingerprints" do
    it "is stable across timestamp and actor changes" do
      comment = create(:page_feedback_comment, status: "approved")
      fingerprint = comment.export_fingerprint

      comment.update!(updated_at: 1.day.from_now)
      comment.update!(reviewed_by: create(:user))

      expect(comment.export_fingerprint).to eq(fingerprint)
    end

    it "changes for every field that affects exported output" do
      comment = create(:page_feedback_comment, status: "approved")
      original_fingerprint = comment.export_fingerprint
      meaningful_changes.each do |attribute, value|
        changed_comment = comment.dup
        changed_comment.public_send("#{attribute}=", value)

        expect(changed_comment.export_fingerprint).not_to eq(original_fingerprint)
      end
    end

    it "includes the host-resolved source location" do
      comment = create(:page_feedback_comment, status: "approved")
      PageFeedback.configuration.source_locator = ->(_comment) { "app/views/projects/show.html.erb" }
      located_fingerprint = comment.export_fingerprint

      PageFeedback.configuration.source_locator = ->(_comment) { "app/views/projects/edit.html.erb" }

      expect(comment.export_fingerprint).not_to eq(located_fingerprint)
    end
  end

  describe "derived state" do
    it "reports approved comments with no items as never exported and ready" do
      comment = create(:page_feedback_comment, status: "approved")

      expect(comment.export_state).to eq("never_exported")
      expect(comment).to be_ready_for_export
    end

    it "reports a matching exported revision as current and not ready" do
      comment = create(:page_feedback_comment, status: "approved")
      create(:page_feedback_export_item, comment:, comment_fingerprint: comment.export_fingerprint)

      expect(comment.export_state).to eq("exported")
      expect(comment).not_to be_ready_for_export
    end

    it "reports only stale revisions as changed and ready again" do
      comment = create(:page_feedback_comment, status: "approved")
      create(:page_feedback_export_item, comment:, comment_fingerprint: comment.export_fingerprint)

      comment.update!(refined_text: "A newer revision")

      expect(comment.export_state).to eq("changed_since_export")
      expect(comment).to be_ready_for_export
    end

    it "never makes pending or rejected comments ready" do
      pending_comment = create(:page_feedback_comment, status: "pending")
      rejected_comment = create(:page_feedback_comment, status: "rejected")

      expect(pending_comment).not_to be_ready_for_export
      expect(rejected_comment).not_to be_ready_for_export
    end

    it "returns only ready approved revisions from the scope" do
      never_exported = create(:page_feedback_comment, status: "approved")
      changed = create(:page_feedback_comment, status: "approved")
      current = create(:page_feedback_comment, status: "approved")
      create(:page_feedback_export_item, comment: changed, comment_fingerprint: "stale")
      create(:page_feedback_export_item, comment: current, comment_fingerprint: current.export_fingerprint)
      create(:page_feedback_comment, status: "pending")

      expect(described_class.ready_for_export).to contain_exactly(never_exported, changed)
    end
  end
end
