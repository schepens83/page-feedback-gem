# frozen_string_literal: true

require "rails_helper"

RSpec.describe "anonymous feedback review", type: :system do
  before { driven_by :rack_test }

  after { PageFeedback.reset_configuration! }

  it "captures from the host widget and approves through the page queue" do
    expect { submit_anonymous_feedback }.to change(PageFeedback::Comment, :count).by(1)
    approve_captured_feedback

    expect(PageFeedback::Comment.last).to have_attributes(
      status: "approved",
      refined_text: "Make the summary more specific.",
      submitter: nil
    )
  end

  def submit_anonymous_feedback
    visit "/"
    expect(page).to have_button("Give page feedback", visible: :all)
    fill_capture_form
    capture_form.find("input[type='submit']", visible: :all).click
  end

  def fill_capture_form
    capture_form.find("textarea[name='comment[comment_text]']", visible: :all).set("Clarify this summary.")
    { page_path: "/", page_title: "Dummy project", css_selector: "#project-summary" }.each do |field, value|
      capture_form.find("input[name='comment[#{field}]']", visible: :all).set(value)
    end
  end

  def approve_captured_feedback
    visit "/feedback/review/pages"
    click_link "Review page"
    fill_in "Refined feedback", with: "Make the summary more specific."
    fill_in "Reviewer notes", with: "Keep the heading concise."
    click_button "Approve"
  end

  def capture_form
    page.find("#page_feedback_widget form", visible: :all)
  end
end
