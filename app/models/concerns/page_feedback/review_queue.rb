# frozen_string_literal: true

require "base64"

module PageFeedback
  # Page routing and derived-state selection for review queues.
  module ReviewQueue
    extend ActiveSupport::Concern

    class_methods do
      # Encode a local page path for use as a nested route segment.
      #
      # @param page_path [String]
      # @return [String]
      def page_key(page_path)
        Base64.urlsafe_encode64(page_path.to_s, padding: false)
      end

      # Decode and validate a nested page route segment.
      #
      # @param key [String]
      # @return [String] a same-origin local path
      # @raise [ActiveRecord::RecordNotFound] when the key is invalid or external
      def page_path_from_key!(key)
        page_path = Base64.urlsafe_decode64(key.to_s)
        return page_path if self::LOCAL_PAGE_PATH_PATTERN.match?(page_path)

        raise ActiveRecord::RecordNotFound, "invalid feedback page key"
      rescue ArgumentError
        raise ActiveRecord::RecordNotFound, "invalid feedback page key"
      end

      # Select comments for one primary review-queue filter.
      #
      # @param filter [String]
      # @return [ActiveRecord::Relation<PageFeedback::Comment>]
      def for_review_filter(filter)
        case filter.to_s
        when "ready" then ready_for_export
        when "exported" then with_export_state("exported")
        when "changed" then with_export_state("changed_since_export")
        when "rejected" then rejected
        when "all" then all
        else pending
        end
      end

      private

      def with_export_state(state)
        candidates = approved.includes(:export_items).to_a
        where(id: candidates.select { |comment| comment.export_state == state }.map(&:id))
      end
    end
  end
end
