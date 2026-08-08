# frozen_string_literal: true

FactoryBot.define do
  factory :page_feedback_comment, class: "PageFeedback::Comment" do
    comment_text { "The save state is unclear." }
    category { "idea" }
    page_path { "/projects/42" }
    page_title { "Project 42" }
    controller_action { "projects#show" }
    css_selector { ".project-summary" }
    element_html { "<section class=\"project-summary\">Summary</section>" }
    context { { "viewport" => "1440x900", "scroll_y" => 812 } }
  end
end
