# frozen_string_literal: true

module PageFeedback
  # Immutable record of pending comments sent to another installation.
  #
  # Forwarding is a fact about where a comment went, like an export, not a
  # review decision: a comment is forwarded when it belongs to a forward, and
  # its status stays pending (ADR 0006). The forward link is rebuilt from the
  # comments whenever it is shown, so a failed import can be retried.
  class Forward < ApplicationRecord
    belongs_to :created_by, polymorphic: true, optional: true
    has_many :forward_items,
             class_name: "PageFeedback::ForwardItem",
             dependent: :restrict_with_error,
             inverse_of: :forward
    has_many :comments, -> { order(:created_at, :id) }, through: :forward_items

    validates :destination_url, presence: true, format: { with: %r{\Ahttps?://}i }

    # Forward the given pending, not yet forwarded comments.
    #
    # @param comments [Enumerable<PageFeedback::Comment>]
    # @param destination_url [String] the receiving installation's handoff page
    # @param actor [ApplicationRecord, nil]
    # @return [PageFeedback::Forward]
    # @raise [ArgumentError] when the selection is empty or too large
    # @raise [ActiveRecord::RecordInvalid] when a comment cannot be forwarded
    def self.create_from!(comments:, destination_url:, actor: nil)
      selected = comments.to_a
      validate_selection!(selected)

      transaction do
        locked = Comment.where(id: selected.map(&:id)).lock.to_a
        locked.each { |comment| ensure_forwardable!(comment) }
        create!(destination_url:, created_by: actor).tap do |forward|
          locked.each { |comment| forward.forward_items.create!(comment:) }
        end
      end
    end

    def self.validate_selection!(comments)
      raise ArgumentError, "comments must not be empty" if comments.empty?
      return if comments.length <= ForwardPayload::MAX_COMMENTS

      raise ArgumentError, "at most #{ForwardPayload::MAX_COMMENTS} comments"
    end
    private_class_method :validate_selection!

    def self.ensure_forwardable!(comment)
      return if comment.awaiting_review?

      comment.errors.add(:base, "is not pending or was already forwarded")
      raise ActiveRecord::RecordInvalid, comment
    end
    private_class_method :ensure_forwardable!

    # The link that carries this forward's comments to the destination.
    #
    # @param source [String] how this installation names itself there
    # @return [String]
    def url(source:)
      "#{destination_url.split('#').first}##{ForwardPayload.fragment(comments:, source:)}"
    end

    # Persisted forwards cannot be changed or removed.
    #
    # @return [Boolean]
    def readonly?
      persisted? || super
    end
  end
end
