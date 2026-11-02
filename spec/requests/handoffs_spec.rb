# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback handoff" do
  after { PageFeedback.reset_configuration! }

  def export_with(text)
    comment = create(:page_feedback_comment, comment_text: text).tap(&:approve!)
    PageFeedback::Export.create_from!(comments: [comment])
  end

  it "shows QR codes on an export that point at this host's unpack page by default" do
    export = export_with("Hand me over")

    get "/feedback/review/exports/#{export.id}"

    codes = response.parsed_body.css(".page-feedback-handoff-codes__list img")
    expect(codes.length).to eq(1)
    svg = Base64.decode64(codes.first["src"].delete_prefix("data:image/svg+xml;base64,"))
    expect(svg).to include("<svg")
    expect(PageFeedback::Handoff.new(export.body, base_url: "http://www.example.com/feedback/review/handoff")
      .parts.first.svg).to eq(svg)
  end

  it "points the codes at the configured handoff URL" do
    export = export_with("Offline host")
    PageFeedback.configuration.handoff_url = "https://reachable.example/feedback/review/handoff"

    get "/feedback/review/exports/#{export.id}"

    src = response.parsed_body.at_css(".page-feedback-handoff-codes__list img")["src"]
    expected = PageFeedback::Handoff.new(export.body, base_url: "https://reachable.example/feedback/review/handoff")
    expect(Base64.decode64(src.delete_prefix("data:image/svg+xml;base64,"))).to eq(expected.parts.first.svg)
  end

  it "renders the unpack page for reviewers" do
    get "/feedback/review/handoff"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("[data-controller='page-feedback-handoff']")).to be_present
  end

  it "keeps the unpack page behind review authorization" do
    PageFeedback.configuration.review_authorizer = ->(_controller) { false }

    get "/feedback/review/handoff"

    expect(response).to have_http_status(:forbidden)
  end
end
