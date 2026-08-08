# frozen_string_literal: true

namespace :page_feedback do
  desc "Diagnose the PageFeedback installation (PAGE_FEEDBACK_FORMAT=json for JSON)"
  task doctor: :environment do
    report = PageFeedback::Diagnostics.new.call
    output = ENV["PAGE_FEEDBACK_FORMAT"] == "json" ? report.to_json : report.to_text
    puts output
    exit 1 unless report.ok?
  end
end
