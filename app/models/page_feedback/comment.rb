# frozen_string_literal: true

module PageFeedback
  # Captured feedback and its independent human review state.
  class Comment < ApplicationRecord
    # Same-origin path shape accepted by persisted comments and replay.
    LOCAL_PAGE_PATH_PATTERN = %r{\A/(?!/)[^?#]*\z}

    belongs_to :submitter, polymorphic: true, optional: true
    belongs_to :reviewed_by, polymorphic: true, optional: true
    has_many :export_items,
             class_name: "PageFeedback::ExportItem",
             dependent: :restrict_with_error,
             inverse_of: :comment
    has_many :exports, through: :export_items

    enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

    validates :comment_text, presence: true
    validates :category, presence: true, inclusion: { in: -> { PageFeedback.configuration.categories.keys } }
    validates :page_path, presence: true, format: { with: LOCAL_PAGE_PATH_PATTERN }

    scope :by_category, ->(category) { where(category:) }
    scope :for_page, ->(path) { where(page_path: path) }
    scope :recent, -> { order(created_at: :desc) }

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

    private

    def transition_to!(status:, approved_at:, rejected_at:, reviewer:)
      update!(status:, approved_at:, rejected_at:, reviewed_by: reviewer)
      self
    end
  end
end
