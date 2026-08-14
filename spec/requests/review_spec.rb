# frozen_string_literal: true

require "base64"
require "rails_helper"

RSpec.describe "PageFeedback review workflow" do
  after { PageFeedback.reset_configuration! }

  around do |example|
    original_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_setting
  end

  def page_key(path)
    Base64.urlsafe_encode64(path, padding: false)
  end

  def queue_path(comment, **query)
    "/feedback/review/pages/#{page_key(comment.page_path)}/comments?#{query.to_query}"
  end

  def page_list
    response.parsed_body.at_css(".page-feedback-page-list")
  end

  def create_grouped_pages
    first = create(:page_feedback_comment, page_path: "/alpha", page_title: "Alpha", category: "bug")
    create(:page_feedback_comment, page_path: "/alpha", page_title: "Alpha", category: "idea")
    create(:page_feedback_comment, page_path: "/alpha", page_title: "Alpha", category: "question").reject!
    create(:page_feedback_comment, page_path: "/beta", page_title: "Beta").approve!
    first
  end

  def exported_and_changed
    exported = create(:page_feedback_comment, page_path: "/exported", page_title: "Exported").tap(&:approve!)
    PageFeedback::Export.create_from!(comments: [exported])
    changed = create(:page_feedback_comment, page_path: "/changed", page_title: "Changed").tap(&:approve!)
    PageFeedback::Export.create_from!(comments: [changed])
    changed.update!(refined_text: "A changed revision")
    [exported, changed]
  end

  it "groups the filtered queue by page and reports full page counts" do
    first = create_grouped_pages

    get "/feedback/review/pages", params: { filter: "pending" }

    expect(response).to have_http_status(:ok)
    expect(page_list.text.squish).to include("Alpha", first.page_path, "2 pending", "1 rejected", "bug 1", "idea 1")
    expect(page_list.css(".page-feedback-page-row").length).to eq(1)
  end

  it "links from every review screen back to the host application root" do
    get "/feedback/review/pages"

    home_link = response.parsed_body.at_css(".page-feedback-review-header .page-feedback-review-home")
    expect(home_link[:href]).to eq("/")
    expect(home_link.text.squish).to include("Back to site")
  end

  it "filters ready feedback by category" do
    create(:page_feedback_comment, page_path: "/bug", page_title: "Bug", category: "bug").approve!
    create(:page_feedback_comment, page_path: "/idea", page_title: "Idea", category: "idea").approve!

    get "/feedback/review/pages", params: { filter: "ready", category: "bug" }

    expect(page_list.text).to include("Bug")
    expect(page_list.text).not_to include("Idea")
  end

  it "filters exported-current revisions" do
    exported_and_changed

    get "/feedback/review/pages", params: { filter: "exported" }
    expect(page_list.text).to include("Exported")
    expect(page_list.text).not_to include("Changed")
  end

  it "filters changed revisions" do
    exported_and_changed

    get "/feedback/review/pages", params: { filter: "changed" }
    expect(page_list.text).to include("Changed")
    expect(page_list.text).not_to include("Exported")
  end

  it "supports rejected and all filters" do
    rejected = create(:page_feedback_comment, page_path: "/rejected", page_title: "Rejected").tap(&:reject!)
    create(:page_feedback_comment, page_path: "/pending", page_title: "Pending")

    get "/feedback/review/pages", params: { filter: "rejected" }
    expect(page_list.text).to include(rejected.page_title)
    expect(page_list.text).not_to include("Pending")
    get "/feedback/review/pages", params: { filter: "all" }
    expect(page_list.text).to include("Rejected", "Pending")
  end

  it "renders a navigable per-page queue and a sandboxed local replay" do
    older = create(:page_feedback_comment, page_path: "/projects/42", comment_text: "Older")
    newer = create(:page_feedback_comment, page_path: older.page_path, comment_text: "Newer")

    get queue_path(older, filter: "pending", id: older.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Older", "2 / 2", "id=#{newer.id}", "page_feedback_replay=1")
    expect(response.body).to include('sandbox="allow-scripts allow-same-origin allow-forms"', "pointer-events: none")
  end

  it "adds selector and scroll context to the local replay URL" do
    comment = create(:page_feedback_comment, css_selector: ".summary", context: { "scroll_y" => 812 })

    get queue_path(comment, filter: "pending")

    expect(response.body).to include("page_feedback_selector=.summary", "page_feedback_scroll=812")
  end

  it "rejects page keys that decode to an external path" do
    external_key = page_key("//evil.example/phish")

    get "/feedback/review/pages/#{external_key}/comments"

    expect(response).to have_http_status(:not_found)
  end

  it "shows complete escaped feedback detail" do
    comment = create(
      :page_feedback_comment,
      comment_text: "Original",
      css_selector: "#summary",
      element_html: "<script>alert('unsafe')</script>"
    )

    get "/feedback/review/comments/#{comment.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Original", "#summary")
    expect(response.body).not_to include("<script>alert")
  end

  it "updates only reviewer-authored fields" do
    comment = create(:page_feedback_comment, comment_text: "Original")
    patch "/feedback/review/comments/#{comment.id}", params: {
      comment: { refined_text: "Refined", reviewer_notes: "Keep layout", comment_text: "Spoofed" }
    }

    expect(response).to redirect_to("/feedback/review/comments/#{comment.id}")
    expect(comment.reload).to have_attributes(refined_text: "Refined", reviewer_notes: "Keep layout")
    expect(comment.comment_text).to eq("Original")
  end

  it "approves with edits and advances while preserving queue filters" do
    reviewer = create(:user)
    current = create(:page_feedback_comment, page_path: "/alpha")
    following = create(:page_feedback_comment, page_path: current.page_path, category: "bug")
    PageFeedback.configuration.current_actor = ->(_controller) { reviewer }

    post "/feedback/review/comments/#{current.id}/approval", params: approval_params(current, following)

    expect(current.reload).to have_attributes(status: "approved", refined_text: "Refined", reviewed_by: reviewer)
    expect(response).to redirect_to(queue_path(current, filter: "pending", category: "bug", id: following.id))
  end

  it "advances to the next matching page when the current page is finished" do
    current = create(:page_feedback_comment, page_path: "/alpha")
    following_page = create(:page_feedback_comment, page_path: "/beta")

    post "/feedback/review/comments/#{current.id}/approval", params: {
      page_key: page_key(current.page_path), filter: "pending"
    }

    expect(response).to redirect_to(queue_path(following_page, filter: "pending"))
  end

  it "links the end of one page queue to the next matching page" do
    current = create(:page_feedback_comment, page_path: "/alpha")
    following_page = create(:page_feedback_comment, page_path: "/beta")

    get queue_path(current, filter: "pending")

    next_link = response.parsed_body.at_css(".page-feedback-queue__navigation a")
    expect(next_link.text.squish).to eq("Next page →")
    expect(next_link[:href]).to eq(queue_path(following_page, filter: "pending"))
  end

  it "rejects while saving reviewer edits" do
    comment = create(:page_feedback_comment)

    post "/feedback/review/comments/#{comment.id}/rejection", params: {
      comment: { reviewer_notes: "Do not implement" }
    }

    expect(comment.reload).to have_attributes(status: "rejected", reviewer_notes: "Do not implement")
  end

  it "removes approval and rejection decisions" do
    approved = create(:page_feedback_comment).tap(&:approve!)
    rejected = create(:page_feedback_comment).tap(&:reject!)

    delete "/feedback/review/comments/#{rejected.id}/rejection"
    delete "/feedback/review/comments/#{approved.id}/approval"

    expect([approved.reload.status, rejected.reload.status]).to eq(%w[pending pending])
  end

  it "bulk approves and rejects selected comments" do
    comments = create_list(:page_feedback_comment, 3)

    post "/feedback/review/bulk_approvals", params: { comment_ids: comments.first(2).map(&:id), filter: "pending" }
    post "/feedback/review/bulk_rejections", params: { comment_ids: [comments.last.id], filter: "pending" }

    expect(comments.map { |comment| comment.reload.status }).to eq(%w[approved approved rejected])
    expect(response).to redirect_to("/feedback/review/pages?filter=pending")
  end

  it "approves all pending feedback across pages as the current reviewer" do
    reviewer = create(:user)
    comments = %w[/alpha /beta].map { |path| create(:page_feedback_comment, page_path: path) }
    PageFeedback.configuration.current_actor = ->(_controller) { reviewer }

    post "/feedback/review/queue_approvals", params: { filter: "pending" }

    expect(comments.map { |comment| comment.reload.status }).to all(eq("approved"))
    expect(comments.map(&:reviewed_by)).to all(eq(reviewer))
  end

  it "limits queue approval by category and leaves rejected feedback unchanged" do
    bug = create(:page_feedback_comment, page_path: "/alpha", category: "bug")
    idea = create(:page_feedback_comment, page_path: "/gamma", category: "idea")
    rejected = create(:page_feedback_comment, page_path: "/delta", category: "bug").tap(&:reject!)

    post "/feedback/review/queue_approvals", params: { filter: "pending", category: "bug" }

    expect([bug.reload.status, idea.reload.status, rejected.reload.status]).to eq(%w[approved pending rejected])
    expect(response).to redirect_to("/feedback/review/pages?category=bug&filter=pending")
  end

  it "offers to approve every pending item from the page overview" do
    create(:page_feedback_comment, page_path: "/alpha")
    create(:page_feedback_comment, page_path: "/beta")

    get "/feedback/review/pages", params: { filter: "pending" }

    form = response.parsed_body.at_css("form[action='/feedback/review/queue_approvals']")
    expect(form.text.squish).to include("Approve all 2 pending")
  end

  it "enforces review authorization on every Phase 5 route" do
    comment = create(:page_feedback_comment)
    PageFeedback.configuration.review_authorizer = ->(_controller) { false }

    expect(review_route_statuses(comment)).to all(eq(403))
  end

  def approval_params(current, following)
    {
      page_key: page_key(current.page_path), next_id: following.id, filter: "pending", category: "bug",
      comment: { refined_text: "Refined", reviewer_notes: "Ship this" }
    }
  end

  def review_route_statuses(comment)
    key = page_key(comment.page_path)
    review_requests(comment, key).map do |verb, path, parameters|
      public_send(verb, path, params: parameters)
      response.status
    end
  end

  def review_requests(comment, key)
    id = comment.id
    [
      [:get, "/feedback/review/pages", {}], [:get, "/feedback/review/pages/#{key}/comments", {}],
      [:get, "/feedback/review/comments/#{id}", {}], [:patch, "/feedback/review/comments/#{id}", { comment: {} }],
      *decision_requests(id),
      [:post, "/feedback/review/bulk_approvals", {}], [:post, "/feedback/review/bulk_rejections", {}],
      [:post, "/feedback/review/queue_approvals", {}]
    ]
  end

  def decision_requests(id)
    [
      [:post, "/feedback/review/comments/#{id}/approval", {}],
      [:delete, "/feedback/review/comments/#{id}/approval", {}],
      [:post, "/feedback/review/comments/#{id}/rejection", {}],
      [:delete, "/feedback/review/comments/#{id}/rejection", {}]
    ]
  end
end
