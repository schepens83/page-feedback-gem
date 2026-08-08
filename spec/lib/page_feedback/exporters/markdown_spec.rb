# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Exporters::Markdown do
  it "groups deterministically by page, page-level feedback, selector, and category priority" do
    idea = create(:page_feedback_comment, category: "idea", page_path: "/b", css_selector: ".card")
    page_bug = create(:page_feedback_comment, category: "bug", page_path: "/b", css_selector: nil)
    question = create(:page_feedback_comment, category: "question", page_path: "/a", css_selector: ".field")

    markdown = described_class.call(comments: [idea, page_bug, question], generated_at: Time.utc(2026, 8, 8, 12, 30))

    expect(markdown.index("## /a")).to be < markdown.index("## /b")
    expect(markdown.index("### Page-level")).to be < markdown.index("### `.card`")
    expect(markdown).to include("- [bug]", "- [question]", "- [idea]")
  end

  it "uses refined text, reviewer notes, source locations, and fenced captured HTML" do
    comment = rich_comment
    PageFeedback.configuration.source_locator = ->(_comment) { "app/views/projects/show.html.erb" }

    markdown = described_class.call(comments: [comment], generated_at: Time.utc(2026, 8, 8, 12, 30))

    expect(markdown).to include("Refined", "Reviewer note: Keep context", "app/views/projects/show.html.erb")
    expect(markdown).to include("```html\n<section>Current</section>\n```")
    expect(markdown).not_to include("Original")
  end

  it "escapes user Markdown and chooses a fence longer than captured backticks" do
    comment = create(
      :page_feedback_comment,
      comment_text: "# heading\n- injected",
      element_html: "<pre>```unsafe```</pre>"
    )

    markdown = described_class.call(comments: [comment], generated_at: Time.utc(2026, 8, 8, 12, 30))

    expect(markdown).to include("\\# heading \\- injected")
    expect(markdown).to include("````html\n<pre>```unsafe```</pre>\n````")
  end

  def rich_comment
    create(
      :page_feedback_comment,
      comment_text: "Original", refined_text: "Refined", reviewer_notes: "Keep context",
      element_html: "<section>Current</section>"
    )
  end
end
