# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback imports" do
  after { PageFeedback.reset_configuration! }

  around do |example|
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  def payload_json(*uuids)
    JSON.generate(
      "format" => "page_feedback.forward", "version" => 1, "source" => "Work laptop",
      "comments" => uuids.map do |uuid|
        { "uuid" => uuid, "category" => "idea", "comment_text" => "Forwarded comment", "page_path" => "/kompas" }
      end
    )
  end

  it "shows the receiving page with an import form for the browser to fill", :aggregate_failures do
    get "/feedback/review/handoff"

    expect(response).to have_http_status(:ok)
    form = response.parsed_body.at_css("form[action='/feedback/review/imports']")
    expect(form.at_css("input[name='payload']")).to be_present
    # The import renders its outcome instead of redirecting, which Turbo would ignore.
    expect(form["data-turbo"]).to eq("false")
  end

  it "imports forwarded comments and reports what happened", :aggregate_failures do
    existing = create(:page_feedback_comment)

    expect do
      post "/feedback/review/imports", params: { payload: payload_json(SecureRandom.uuid, existing.uuid) }
    end.to change(PageFeedback::Comment, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.body).to include("1 comment imported", "from Work laptop", "already here and skipped")
  end

  it "says why an unreadable forward imported nothing" do
    post "/feedback/review/imports", params: { payload: "{}" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nothing imported", "not a page feedback forward")
  end

  it "keeps import behind review authorization" do
    PageFeedback.configuration.review_authorizer = ->(_controller) { false }

    expect do
      post "/feedback/review/imports", params: { payload: payload_json(SecureRandom.uuid) }
    end.not_to change(PageFeedback::Comment, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "names where an imported comment came from in review", :aggregate_failures do
    post "/feedback/review/imports", params: { payload: payload_json(uuid = SecureRandom.uuid) }
    comment = PageFeedback::Comment.find_by!(uuid:)
    comment.update!(submitter_label: "Sander")

    get "/feedback/review/comments/#{comment.id}"
    expect(response.body).to include("Forwarded from", "Work laptop", "Sander")

    get "/feedback/review/pages/#{PageFeedback::Comment.page_key('/kompas')}/comments"
    expect(response.body).to include("Submitted by Sander via Work laptop")
  end
end
