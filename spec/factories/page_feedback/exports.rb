# frozen_string_literal: true

require "digest"

FactoryBot.define do
  factory :page_feedback_export, class: "PageFeedback::Export" do
    format { "markdown" }
    body { "# Feedback Export\n" }
    body_digest { Digest::SHA256.hexdigest(body) }
  end

  factory :page_feedback_export_item, class: "PageFeedback::ExportItem" do
    association :export, factory: :page_feedback_export
    association :comment, factory: :page_feedback_comment
    comment_fingerprint { comment.export_fingerprint }
    sequence(:position)
  end
end
