# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Export, type: :model do
  it "requires the immutable body and its digest" do
    export = build(:page_feedback_export, body: nil, body_digest: nil)

    expect(export).not_to be_valid
    expect(export.errors).to include(:body, :body_digest)
  end

  describe ".create_from!" do
    let(:actor) { create(:user) }
    let(:first_comment) { create(:page_feedback_comment, status: "approved", page_path: "/first") }
    let(:second_comment) { create(:page_feedback_comment, status: "approved", page_path: "/second") }
    let(:formatter) do
      Class.new do
        def self.call(comments:, generated_at:)
          "#{generated_at.iso8601}:#{comments.map(&:page_path).join(',')}"
        end
      end
    end
    let(:ordered_export) do
      travel_to Time.zone.parse("2026-08-08 16:00:00") do
        described_class.create_from!(comments: [second_comment, first_comment], actor:, formatter:)
      end
    end

    def failing_formatter
      Class.new do
        def self.call(comments:, generated_at:)
          raise "formatter failed for #{comments.length} at #{generated_at}"
        end
      end
    end

    def static_formatter
      ->(**) { "same body" }
    end

    it "stores one body and exact ordered membership", :aggregate_failures do
      expect(ordered_export.body).to eq("2026-08-08T16:00:00Z:/second,/first")
      expect(ordered_export.body_digest).to eq(Digest::SHA256.hexdigest(ordered_export.body))
      expect(ordered_export.created_by).to eq(actor)
      expect(ordered_export.export_items.pluck(:comment_id, :position)).to eq(
        [[second_comment.id, 0], [first_comment.id, 1]]
      )
      expect(ordered_export.export_items.map(&:comment_fingerprint)).to eq(
        [second_comment.export_fingerprint, first_comment.export_fingerprint]
      )
    end

    it "rejects comments that are not currently ready and rolls back" do
      pending_comment = create(:page_feedback_comment, status: "pending")

      expect do
        described_class.create_from!(comments: [first_comment, pending_comment], actor:, formatter:)
      end.to raise_error(ActiveRecord::RecordInvalid)
        .and not_change(described_class, :count)
        .and not_change(PageFeedback::ExportItem, :count)
    end

    it "rolls back when the formatter fails" do
      travel_to Time.zone.parse("2026-08-08 14:00:00") do
        expect do
          described_class.create_from!(comments: [first_comment], actor:, formatter: failing_formatter)
        end.to raise_error("formatter failed for 1 at 2026-08-08 14:00:00 UTC")
          .and not_change(described_class, :count)
          .and not_change(PageFeedback::ExportItem, :count)
      end
    end

    it "rejects an empty selection" do
      expect do
        described_class.create_from!(comments: [], actor:, formatter:)
      end.to raise_error(ArgumentError, "comments must not be empty")
    end

    it "allows separate exports to store the same intentional body" do
      first_export = described_class.create_from!(comments: [first_comment], actor:, formatter: static_formatter)
      second_export = described_class.create_from!(comments: [second_comment], actor:, formatter: static_formatter)

      expect(first_export.body_digest).to eq(second_export.body_digest)
      expect(described_class.where(body_digest: first_export.body_digest).count).to eq(2)
    end
  end

  describe "immutability" do
    it "prevents changing or destroying a persisted export" do
      export = create(:page_feedback_export)

      expect { export.update!(body: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { export.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(export.reload.body).to eq("# Feedback Export\n")
    end
  end
end
