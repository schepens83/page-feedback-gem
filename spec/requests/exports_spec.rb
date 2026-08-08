# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback exports" do
  after { PageFeedback.reset_configuration! }

  around do |example|
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  def ready_comment(attributes = {})
    create(:page_feedback_comment, **attributes).tap(&:approve!)
  end

  it "previews selected ready revisions without creating an export" do
    selected = ready_comment(comment_text: "Selected feedback")
    ready_comment(comment_text: "Ignored feedback")

    expect do
      get "/feedback/review/exports/new", params: { comment_ids: [selected.id] }
    end.not_to change(PageFeedback::Export, :count)

    expect(response.body).to include("Selected feedback", "comment_ids[]", selected.id.to_s)
    expect(response.body).not_to include("Ignored feedback")
  end

  it "creates one immutable export from exact selected order and host actor" do
    actor = create(:user)
    first = ready_comment(comment_text: "First")
    second = ready_comment(comment_text: "Second")
    PageFeedback.configuration.current_actor = ->(_controller) { actor }

    post "/feedback/review/exports", params: { comment_ids: [second.id, first.id] }

    export = PageFeedback::Export.last
    expect(export).to have_attributes(created_by: actor)
    expect(export.export_items.order(:position).pluck(:comment_id)).to eq([second.id, first.id])
    expect(response).to redirect_to("/feedback/review/exports/#{export.id}")
  end

  it "shows export history and immutable membership" do
    comment = ready_comment(comment_text: "Stored once")
    export = PageFeedback::Export.create_from!(comments: [comment], label: "Legacy Diagnostic Engine import")

    get "/feedback/review/exports"
    expect(response.body).to include("Legacy Diagnostic Engine import", "Export ##{export.id}", "1 revision")
  end

  it "shows the exact stored body and included feedback", :aggregate_failures do
    actor = create(:user, email: "reviewer@example.test")
    comment = ready_comment(comment_text: "Stored once")
    export = PageFeedback::Export.create_from!(comments: [comment], actor:, label: "Imported snapshot")

    get "/feedback/review/exports/#{export.id}"
    expect(response.parsed_body.at_css(".page-feedback-export-body").text).to eq(export.body)
    expect(response.body).to include(comment.comment_text)
    expect(response.body).to include("Imported snapshot", "Export ##{export.id}")
    expect(response.body).to include("Markdown", "Created by reviewer@example.test")
    expect(response.body).to include("data-page-feedback-copy-text-value=")
  end

  it "downloads byte-for-byte the same stored Markdown shown and copied" do
    comment = ready_comment
    export = PageFeedback::Export.create_from!(comments: [comment])

    get "/feedback/review/exports/#{export.id}.md"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to eq(export.body)
  end

  it "uses the configured formatter contract during creation" do
    comment = ready_comment
    PageFeedback.configuration.export_formatter = lambda do |comments:, generated_at:|
      ids = comments.map(&:id).join(",")
      "custom:#{ids}:#{generated_at.class}"
    end

    post "/feedback/review/exports", params: { comment_ids: [comment.id] }

    expect(PageFeedback::Export.last.body).to start_with("custom:#{comment.id}:")
  end

  it "enforces review authorization for every export route" do
    export = PageFeedback::Export.create_from!(comments: [ready_comment])
    PageFeedback.configuration.review_authorizer = ->(_controller) { false }

    statuses = export_route_requests(export).map { |request| request.call && response.status }

    expect(statuses).to all(eq(403))
  end

  def export_route_requests(export)
    [
      -> { get "/feedback/review/exports" }, -> { get "/feedback/review/exports/new" },
      -> { post "/feedback/review/exports", params: { comment_ids: [] } },
      -> { get "/feedback/review/exports/#{export.id}" }, -> { get "/feedback/review/exports/#{export.id}.md" }
    ]
  end
end
