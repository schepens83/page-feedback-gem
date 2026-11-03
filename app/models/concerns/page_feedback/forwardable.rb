# frozen_string_literal: true

require "securerandom"

module PageFeedback
  # A comment's identity across installations and its forwarding state
  # (docs/WORKFLOW.md, "Forwarding"; ADR 0006).
  module Forwardable
    extend ActiveSupport::Concern

    # Shape of the identity shared by a comment's copies across installations.
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
    # Maximum accepted length of an origin or submitter label.
    MAX_LABEL_LENGTH = 255

    included do
      has_many :forward_items,
               class_name: "PageFeedback::ForwardItem",
               dependent: :restrict_with_error,
               inverse_of: :comment

      validates :uuid, presence: true, format: { with: UUID_PATTERN }, uniqueness: true
      validates :origin, :submitter_label, length: { maximum: MAX_LABEL_LENGTH }, allow_nil: true

      before_validation :assign_uuid, on: :create

      scope :forwarded, -> { where(id: ForwardItem.select(:comment_id)) }
      scope :unforwarded, -> { where.not(id: ForwardItem.select(:comment_id)) }
      # Pending comments still to be judged here: forwarded ones are judged elsewhere.
      scope :awaiting_review, -> { pending.unforwarded }
    end

    # Whether this comment was sent to another installation.
    #
    # @return [Boolean]
    def forwarded?
      forward_items.loaded? ? forward_items.any? : forward_items.exists?
    end

    # Whether this comment is pending and still to be judged here.
    #
    # @return [Boolean]
    def awaiting_review?
      pending? && !forwarded?
    end

    # Who submitted this comment: the host actor, or for an imported comment the
    # label its source installation sent.
    #
    # @return [String, nil]
    def submitter_display_label
      return PageFeedback.configuration.actor_label.call(submitter) if submitter

      submitter_label.presence
    end

    private

    def assign_uuid
      self.uuid = uuid.presence&.downcase || SecureRandom.uuid
    end
  end
end
