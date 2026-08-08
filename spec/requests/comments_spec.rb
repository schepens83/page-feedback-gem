# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback comments" do
  after { PageFeedback.reset_configuration! }

  def valid_comment_params
    { comment: valid_comment_attributes }
  end

  def valid_comment_attributes
    {
      comment_text: "Make the saved state visible.",
      category: "idea",
      page_path: "/projects/42",
      page_title: "Project 42",
      controller_action: "projects#show",
      css_selector: ".project-summary",
      element_html: "<section>Summary</section>",
      context: { viewport: "1440x900", scroll_y: 812 }
    }
  end

  def legacy_context
    {
      parentHTML: "<main>Parent</main>",
      scrollY: "812",
      consoleErrors: [{ message: "Failed", timestampMs: 123 }].to_json,
      navigationHistory: "not-json"
    }
  end

  def post_comment(params: valid_comment_params, as: nil, headers: {})
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    post "/feedback/comments", params:, as:, headers:
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  it "creates anonymous feedback as JSON" do
    post_comment(as: :json)

    comment = PageFeedback::Comment.last
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to eq("id" => comment.id, "status" => "pending")
    expect(comment.submitter).to be_nil
  end

  it "attributes the host actor and ignores spoofed identities and status" do
    actor = create(:user)
    PageFeedback.configuration.current_actor = ->(_controller) { actor }
    params = valid_comment_params
    params[:comment].merge!(submitter_id: create(:user).id, reviewed_by_id: create(:user).id, status: "approved")

    post_comment(params:, as: :json)

    comment = PageFeedback::Comment.last
    expect(comment.submitter).to eq(actor)
    expect(comment.reviewed_by).to be_nil
    expect(comment).to be_pending
  end

  it "normalizes legacy context keys and malformed arrays" do
    params = valid_comment_params
    params[:comment][:context] = legacy_context

    post_comment(params:, as: :json)

    expect(PageFeedback::Comment.last.context).to eq(
      "parent_html" => "<main>Parent</main>",
      "viewport" => nil,
      "scroll_y" => 812,
      "console_errors" => [{ "message" => "Failed", "timestamp_ms" => 123 }],
      "navigation_history" => []
    )
  end

  it "returns JSON validation errors for external paths and oversized fields" do
    params = valid_comment_params
    params[:comment][:page_path] = "//evil.example/path"
    params[:comment][:element_html] = "x" * 2_501

    expect { post_comment(params:, as: :json) }.not_to change(PageFeedback::Comment, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("errors")).to include("page_path", "element_html")
  end

  it "rejects query-bearing paths and oversized context collections" do
    params = valid_comment_params
    params[:comment][:page_path] = "/projects/42?tab=private"
    params[:comment][:context][:console_errors] = Array.new(11) { { message: "Failed" } }

    expect { post_comment(params:, as: :json) }.not_to change(PageFeedback::Comment, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("errors")).to include("page_path", "context")
  end

  it "redirects an HTML success back to the host page" do
    post_comment(headers: { "HTTP_REFERER" => "http://www.example.com/projects/42" })

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to("http://www.example.com/projects/42")
  end

  it "renders a usable HTML validation response" do
    params = valid_comment_params
    params[:comment][:comment_text] = ""

    post_comment(params:)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Feedback could not be saved")
  end

  it "returns two Turbo Stream operations on success" do
    post_comment(headers: { "ACCEPT" => Mime[:turbo_stream].to_s })

    expect(response).to have_http_status(:created)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include(
      'action="replace" target="page_feedback_modal_comment"',
      'action="append" target="page_feedback_toasts_comment"'
    )
  end

  it "reopens the populated Turbo form on validation failure" do
    params = valid_comment_params
    params[:comment][:comment_text] = ""

    post_comment(params:, headers: { "ACCEPT" => Mime[:turbo_stream].to_s })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      'action="replace" target="page_feedback_modal_comment"',
      "Feedback could not be saved",
      "/projects/42"
    )
  end
end
