# frozen_string_literal: true

require "rails_helper"
require "zlib"

RSpec.describe PageFeedback::Forward do
  let(:destination_url) { "https://primary.example/feedback/review/handoff" }

  def forwarded_payload(url)
    fragment = url.split("#pf2.", 2).last
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    JSON.parse(inflater.inflate(Base64.urlsafe_decode64(fragment)).force_encoding("UTF-8"))
  ensure
    inflater&.close
  end

  it "records which pending comments went where, without changing their status", :aggregate_failures do
    actor = create(:user)
    comments = create_list(:page_feedback_comment, 2)

    forward = described_class.create_from!(comments:, destination_url:, actor:)

    expect(forward).to have_attributes(destination_url:, created_by: actor)
    expect(forward.comments).to match_array(comments)
    expect(comments.map(&:reload)).to all(be_pending.and(be_forwarded))
  end

  it "only forwards comments that are pending and not forwarded yet", :aggregate_failures do
    approved = create(:page_feedback_comment).tap(&:approve!)
    forwarded = create(:page_feedback_comment)
    described_class.create_from!(comments: [forwarded], destination_url:)

    [approved, forwarded].each do |comment|
      expect { described_class.create_from!(comments: [comment], destination_url:) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
    expect(described_class.count).to eq(1)
  end

  it "refuses an empty selection or a non-http destination", :aggregate_failures do
    expect { described_class.create_from!(comments: [], destination_url:) }.to raise_error(ArgumentError)
    expect { described_class.create_from!(comments: [create(:page_feedback_comment)], destination_url: "javascript:x") }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "builds a link to the destination that carries every comment", :aggregate_failures do
    comments = create_list(:page_feedback_comment, 2)
    forward = described_class.create_from!(comments:, destination_url:)

    url = forward.url(source: "Work laptop")
    expect(url).to start_with("#{destination_url}#pf2.")
    payload = forwarded_payload(url)
    expect(payload["source"]).to eq("Work laptop")
    expect(payload["comments"].pluck("uuid")).to match_array(comments.map(&:uuid))
  end

  it "is immutable once created" do
    forward = described_class.create_from!(comments: [create(:page_feedback_comment)], destination_url:)

    expect { forward.update!(destination_url: "https://elsewhere.example") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "keeps forwarded comments out of the pending queue and in the forwarded one", :aggregate_failures do
    waiting = create(:page_feedback_comment)
    sent = create(:page_feedback_comment)
    described_class.create_from!(comments: [sent], destination_url:)

    expect(PageFeedback::Comment.for_review_filter("pending")).to contain_exactly(waiting)
    expect(PageFeedback::Comment.for_review_filter("forwarded")).to contain_exactly(sent)
    expect(PageFeedback::Comment.for_review_filter("all")).to contain_exactly(waiting, sent)
  end
end
