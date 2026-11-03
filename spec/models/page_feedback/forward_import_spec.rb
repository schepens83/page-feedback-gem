# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::ForwardImport do
  after { PageFeedback.reset_configuration! }

  def entry(overrides = {})
    {
      "uuid" => SecureRandom.uuid, "category" => "bug", "comment_text" => "Week view hides Friday",
      "refined_text" => nil, "page_path" => "/kompas", "page_title" => "Kompas",
      "controller_action" => "kompas/weeks#show", "css_selector" => "main .week",
      "element_html" => "<div class=\"week\">…</div>", "context" => { "viewport" => "1440x900", "scroll_y" => 3 },
      "created_at" => "2026-11-02T09:15:00Z", "submitter_label" => "Sander"
    }.merge(overrides)
  end

  def payload(*entries, source: "Work laptop")
    { "format" => "page_feedback.forward", "version" => 1, "source" => source, "comments" => entries }
  end

  it "creates pending comments that keep their identity and origin", :aggregate_failures do
    forwarded = entry
    result = described_class.new(payload(forwarded)).call

    comment = PageFeedback::Comment.find_by!(uuid: forwarded["uuid"])
    expect(result).to have_attributes(source: "Work laptop", imported: [comment], skipped: 0, invalid: 0)
    expect(comment).to have_attributes(
      status: "pending", origin: "Work laptop", submitter: nil, submitter_label: "Sander", reviewed_by: nil
    )
    expect(comment.submitter_display_label).to eq("Sander")
  end

  it "keeps the captured text, element, context and capture time", :aggregate_failures do
    forwarded = entry
    described_class.new(payload(forwarded)).call

    comment = PageFeedback::Comment.find_by!(uuid: forwarded["uuid"])
    expect(comment).to have_attributes(
      comment_text: "Week view hides Friday", category: "bug", element_html: "<div class=\"week\">…</div>",
      created_at: Time.utc(2026, 11, 2, 9, 15)
    )
    expect(comment.context).to include("viewport" => "1440x900", "scroll_y" => 3)
  end

  it "skips comments that are already here, so importing twice changes nothing" do
    forwarded = entry
    described_class.new(payload(forwarded)).call

    result = nil
    expect { result = described_class.new(payload(forwarded, entry)).call }
      .to change(PageFeedback::Comment, :count).by(1)
    expect(result).to have_attributes(skipped: 1, invalid: 0)
  end

  it "holds imported comments to capture's rules", :aggregate_failures do
    result = described_class.new(payload(
                                   entry("page_path" => "https://evil.example/x"),
                                   entry("comment_text" => ""),
                                   entry("uuid" => "not-a-uuid"),
                                   entry("element_html" => "x" * 10_000),
                                   "not a comment"
                                 )).call

    expect(result).to have_attributes(imported: [], invalid: 5)
  end

  it "cannot set review state and falls back to the default category", :aggregate_failures do
    forwarded = entry("status" => "approved", "reviewer_notes" => "trust me", "category" => "unknown")
    described_class.new(payload(forwarded)).call

    comment = PageFeedback::Comment.find_by!(uuid: forwarded["uuid"])
    expect(comment).to have_attributes(status: "pending", reviewer_notes: nil, category: "idea")
  end

  it "never dates a comment in the future and survives a missing time" do
    future = entry("created_at" => 1.year.from_now.iso8601)
    missing = entry("created_at" => "yesterday")
    freeze_time do
      described_class.new(payload(future, missing)).call

      expect(PageFeedback::Comment.where(uuid: [future["uuid"], missing["uuid"]]).pluck(:created_at))
        .to all(eq(Time.current))
    end
  end
end
