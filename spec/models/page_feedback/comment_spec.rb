# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Comment, type: :model do
  subject(:comment) { build(:page_feedback_comment) }

  after { PageFeedback.reset_configuration! }

  describe "validations" do
    it "accepts a complete local-page comment" do
      expect(comment).to be_valid
      expect(comment.status).to eq("pending")
    end

    it "requires feedback text and a local page path" do
      comment.comment_text = nil
      comment.page_path = "https://example.test/projects/42"

      expect(comment).not_to be_valid
      expect(comment.errors).to include(:comment_text, :page_path)
    end

    it "rejects unknown review states" do
      comment.status = "exported"

      expect(comment).not_to be_valid
      expect(comment.errors[:status]).not_to be_empty
    end

    it "validates category keys against host configuration" do
      PageFeedback.configuration.categories = { "copy" => "Copy" }

      expect(comment).not_to be_valid

      comment.category = "copy"
      expect(comment).to be_valid
    end
  end

  describe "actor associations" do
    it "persists anonymous comments" do
      expect(create(:page_feedback_comment, submitter: nil).submitter).to be_nil
    end

    it "persists polymorphic submitter and reviewer records" do
      submitter = create(:user)
      reviewer = create(:user)

      persisted_comment = create(
        :page_feedback_comment,
        submitter:,
        reviewed_by: reviewer
      )

      expect(persisted_comment.submitter).to eq(submitter)
      expect(persisted_comment.reviewed_by).to eq(reviewer)
    end
  end

  describe "effective text" do
    it "prefers a nonblank reviewer refinement" do
      comment.refined_text = "Make the saved state visible."

      expect(comment.effective_text).to eq("Make the saved state visible.")
    end

    it "falls back to the submitted text" do
      comment.refined_text = "  "

      expect(comment.effective_text).to eq(comment.comment_text)
    end
  end

  describe "review transitions" do
    let(:reviewer) { create(:user) }

    it "approves atomically and clears an earlier rejection", :aggregate_failures do
      travel_to Time.zone.parse("2026-08-08 15:00:00") do
        comment.update!(status: "rejected", rejected_at: 1.day.ago)

        comment.approve!(reviewer:)

        expect(comment).to be_approved
        expect(comment.approved_at).to eq(Time.current)
        expect(comment.rejected_at).to be_nil
        expect(comment.reviewed_by).to eq(reviewer)
      end
    end

    it "rejects atomically and clears an earlier approval", :aggregate_failures do
      travel_to Time.zone.parse("2026-08-08 15:00:00") do
        comment.update!(status: "approved", approved_at: 1.day.ago)

        comment.reject!(reviewer:)

        expect(comment).to be_rejected
        expect(comment.rejected_at).to eq(Time.current)
        expect(comment.approved_at).to be_nil
        expect(comment.reviewed_by).to eq(reviewer)
      end
    end

    it "returns a decision to pending and records a nil reviewer", :aggregate_failures do
      comment.update!(
        status: "approved",
        approved_at: Time.current,
        reviewed_by: reviewer
      )

      comment.return_to_pending!(reviewer: nil)

      expect(comment).to be_pending
      expect(comment.approved_at).to be_nil
      expect(comment.rejected_at).to be_nil
      expect(comment.reviewed_by).to be_nil
    end
  end

  describe "scopes" do
    it "filters by review state, category, and page" do
      matching = create(:page_feedback_comment, category: "bug", page_path: "/matching")
      create(:page_feedback_comment, status: "approved", category: "idea", page_path: "/other")

      expect(described_class.pending).to contain_exactly(matching)
      expect(described_class.by_category("bug")).to contain_exactly(matching)
      expect(described_class.for_page("/matching")).to contain_exactly(matching)
    end

    it "orders recent comments newest first" do
      older = create(:page_feedback_comment, created_at: 2.days.ago)
      newer = create(:page_feedback_comment, created_at: 1.day.ago)

      expect(described_class.recent).to eq([newer, older])
    end
  end
end
