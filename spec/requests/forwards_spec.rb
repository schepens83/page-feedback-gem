# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback forwards" do
  let(:handoff_url) { "https://primary.example/feedback/review/handoff" }

  after { PageFeedback.reset_configuration! }

  around do |example|
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  before do
    PageFeedback.configuration.handoff_url = handoff_url
    PageFeedback.configuration.instance_name = "Work laptop"
  end

  it "offers to forward pending feedback on the review overview" do
    create(:page_feedback_comment)

    get "/feedback/review/pages"

    expect(response.body).to include("Forward 1 pending comment to primary.example")
  end

  it "forwards every pending comment and shows the link that carries them", :aggregate_failures do
    comments = create_list(:page_feedback_comment, 2)

    post "/feedback/review/forwards"

    forward = PageFeedback::Forward.last
    expect(response).to redirect_to("/feedback/review/forwards/#{forward.id}")
    expect(forward.comments).to match_array(comments)

    follow_redirect!
    link = response.parsed_body.at_css("a[target='_blank']")
    expect(link["href"]).to start_with("#{handoff_url}#pf2.")
    expect(link["rel"]).to eq("noopener")
    expect(response.body).to include("2 comments ready to send")
  end

  it "forwards only the selected category and leaves forwarded comments out of later forwards" do
    bug = create(:page_feedback_comment, category: "bug")
    create(:page_feedback_comment, category: "idea")

    post "/feedback/review/forwards", params: { category: "bug" }
    expect(PageFeedback::Forward.last.comments).to contain_exactly(bug)

    post "/feedback/review/forwards", params: { category: "bug" }
    expect(PageFeedback::Forward.count).to eq(1)
  end

  it "lists forward history" do
    PageFeedback::Forward.create_from!(comments: [create(:page_feedback_comment)], destination_url: handoff_url)

    get "/feedback/review/forwards"

    expect(response.body).to include("Forward #", "1 comment")
  end

  it "does not offer forwarding when no destination is configured", :aggregate_failures do
    PageFeedback.configuration.handoff_url = nil
    create(:page_feedback_comment)

    get "/feedback/review/pages"
    expect(response.body).not_to include("Forward 1")

    post "/feedback/review/forwards"
    expect(response).to have_http_status(:not_found)
  end

  it "keeps forwarding behind review authorization" do
    PageFeedback.configuration.review_authorizer = ->(_controller) { false }
    create(:page_feedback_comment)

    post "/feedback/review/forwards"

    expect(response).to have_http_status(:forbidden)
  end
end
