# frozen_string_literal: true

module PageFeedback
  # Vendor-neutral representations of approved feedback revisions.
  module Exporters
    # Public formatter boundary. Phase 6 adds the complete grouped Markdown body.
    class Markdown
      # Render feedback as UTF-8 Markdown.
      #
      # @param comments [Enumerable] approved comment revisions to render
      # @param generated_at [Time] timestamp to display in the export
      # @return [String] a UTF-8 Markdown document
      def self.call(comments:, generated_at:)
        comment_count = comments.to_a.length
        "# Feedback Export\n\nGenerated: #{generated_at}\n\nComments: #{comment_count}\n".encode(Encoding::UTF_8)
      end
    end
  end
end
