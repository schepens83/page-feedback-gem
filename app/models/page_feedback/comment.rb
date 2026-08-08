# frozen_string_literal: true

require "digest"
require "json"

module PageFeedback
  # Captured feedback and its independent human review state.
  class Comment < ApplicationRecord
    # Same-origin path shape accepted by persisted comments and replay.
    LOCAL_PAGE_PATH_PATTERN = %r{\A/(?!/)[^?#]*\z}
    # Comment attributes whose values contribute to exported output.
    FINGERPRINT_FIELDS = %i[
      category effective_text reviewer_notes page_path page_title
      controller_action css_selector element_html
    ].freeze
    # Review queue filters accepted at the request boundary.
    REVIEW_FILTERS = %w[pending ready exported changed rejected all].freeze
    # Maximum accepted feedback body length.
    MAX_COMMENT_TEXT_LENGTH = 10_000
    # Maximum accepted same-origin path length.
    MAX_PAGE_PATH_LENGTH = 2_000
    # Maximum accepted page title length.
    MAX_PAGE_TITLE_LENGTH = 500
    # Maximum accepted controller/action label length.
    MAX_CONTROLLER_ACTION_LENGTH = 255
    # Maximum accepted CSS selector length.
    MAX_CSS_SELECTOR_LENGTH = 2_000
    # Maximum accepted selected-element HTML length.
    MAX_ELEMENT_HTML_LENGTH = 2_500
    # Maximum accepted parent-element HTML length.
    MAX_PARENT_HTML_LENGTH = 1_250
    # Maximum number of captured console error summaries.
    MAX_CONSOLE_ERRORS = 10
    # Maximum number of captured navigation entries.
    MAX_NAVIGATION_EVENTS = 5

    include PageFeedback::CapturedContext
    include PageFeedback::ReviewQueue

    belongs_to :submitter, polymorphic: true, optional: true
    belongs_to :reviewed_by, polymorphic: true, optional: true
    has_many :export_items,
             class_name: "PageFeedback::ExportItem",
             dependent: :restrict_with_error,
             inverse_of: :comment
    has_many :exports, through: :export_items

    enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

    validates :category, presence: true, inclusion: { in: -> { PageFeedback.configuration.categories.keys } }
    validates :page_path, presence: true, format: { with: LOCAL_PAGE_PATH_PATTERN }

    scope :by_category, ->(category) { where(category:) }
    scope :for_page, ->(path) { where(page_path: path) }
    scope :recent, -> { order(created_at: :desc) }
    scope :ready_for_export, lambda {
      candidates = approved.includes(:export_items).to_a
      where(id: candidates.select(&:ready_for_export?).map(&:id))
    }

    # Reviewer-authored text when present, otherwise the submitted feedback.
    #
    # @return [String]
    def effective_text
      refined_text.presence || comment_text
    end

    # Mark this revision approved by the supplied host actor.
    #
    # @param reviewer [ApplicationRecord, nil]
    # @return [PageFeedback::Comment]
    def approve!(reviewer: nil)
      transition_to!(
        status: "approved",
        approved_at: Time.current,
        rejected_at: nil,
        reviewer:
      )
    end

    # Mark this revision rejected by the supplied host actor.
    #
    # @param reviewer [ApplicationRecord, nil]
    # @return [PageFeedback::Comment]
    def reject!(reviewer: nil)
      transition_to!(
        status: "rejected",
        approved_at: nil,
        rejected_at: Time.current,
        reviewer:
      )
    end

    # Clear the current review decision.
    #
    # @param reviewer [ApplicationRecord, nil]
    # @return [PageFeedback::Comment]
    def return_to_pending!(reviewer: nil)
      transition_to!(
        status: "pending",
        approved_at: nil,
        rejected_at: nil,
        reviewer:
      )
    end

    # Host-resolved source file associated with this captured page.
    #
    # @return [String, nil]
    def source_location
      PageFeedback.configuration.source_locator.call(self)
    end

    # Digest of only the fields that affect exported output.
    #
    # @return [String] SHA-256 hexadecimal digest
    def export_fingerprint
      Digest::SHA256.hexdigest(JSON.generate(export_fingerprint_payload))
    end

    # Current relationship between this revision and immutable exports.
    #
    # @return [String] never_exported, exported, or changed_since_export
    def export_state
      items = export_items.to_a
      return "never_exported" if items.empty?
      return "exported" if items.any? { |item| item.comment_fingerprint == export_fingerprint }

      "changed_since_export"
    end

    # Whether this approved revision needs a new export snapshot.
    #
    # @return [Boolean]
    def ready_for_export?
      approved? && export_state != "exported"
    end

    private

    def export_fingerprint_payload
      FINGERPRINT_FIELDS.index_with { |field| public_send(field) }.merge(source_location:)
    end

    def transition_to!(status:, approved_at:, rejected_at:, reviewer:)
      update!(status:, approved_at:, rejected_at:, reviewed_by: reviewer)
      self
    end
  end
end
