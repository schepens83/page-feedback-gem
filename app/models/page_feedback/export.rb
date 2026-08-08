# frozen_string_literal: true

require "digest"

module PageFeedback
  # Immutable rendered snapshot of exact approved comment revisions.
  class Export < ApplicationRecord
    belongs_to :created_by, polymorphic: true, optional: true
    has_many :export_items,
             -> { order(:position) },
             class_name: "PageFeedback::ExportItem",
             dependent: :restrict_with_error,
             inverse_of: :export
    has_many :comments, through: :export_items

    validates :format, :body, :body_digest, presence: true
    validates :label, length: { maximum: 255 }, allow_nil: true

    # Atomically render and persist the selected ready revisions.
    #
    # @param comments [Enumerable<PageFeedback::Comment>]
    # @param actor [ApplicationRecord, nil]
    # @param formatter [#call]
    # @param label [String, nil] immutable provenance shown in export history
    # @return [PageFeedback::Export]
    def self.create_from!(comments:, actor: nil, formatter: PageFeedback.configuration.export_formatter, label: nil)
      selected_comments = comments.to_a
      validate_selection!(selected_comments)

      transaction do
        locked_comments = lock_selected_comments(selected_comments)
        ensure_all_ready!(locked_comments)
        locked_comments.each(&:source_location)
        create_snapshot!(comments: locked_comments, actor:, formatter:, label:)
      end
    end

    # Persisted exports cannot be updated or destroyed.
    #
    # @return [Boolean]
    def readonly?
      persisted? || super
    end

    class << self
      private

      def validate_selection!(comments)
        raise ArgumentError, "comments must not be empty" if comments.empty?
        raise ArgumentError, "comments must be persisted" if comments.any?(&:new_record?)
        raise ArgumentError, "comments must be unique" if comments.map(&:id).uniq.length != comments.length
      end

      def lock_selected_comments(comments)
        comments_by_id = Comment.where(id: comments.map(&:id)).lock.index_by(&:id)
        comments.map { |comment| comments_by_id.fetch(comment.id) }
      end

      def ensure_all_ready!(comments)
        comments.each do |comment|
          next if comment.ready_for_export?

          comment.errors.add(:base, "is not ready for export")
          raise ActiveRecord::RecordInvalid, comment
        end
      end

      def create_snapshot!(comments:, actor:, formatter:, label:)
        generated_at = Time.current
        body = render_body(formatter:, comments:, generated_at:)
        export = persist_body!(body:, actor:, label:)
        create_items!(export:, comments:)
        export
      end

      def render_body(formatter:, comments:, generated_at:)
        body = formatter.call(comments:, generated_at:)
        raise TypeError, "formatter must return a String" unless body.is_a?(String)

        body.encode(Encoding::UTF_8)
      end

      def persist_body!(body:, actor:, label:)
        create!(body:, body_digest: Digest::SHA256.hexdigest(body), created_by: actor, label:)
      end

      def create_items!(export:, comments:)
        comments.each_with_index do |comment, position|
          export.export_items.create!(
            comment:,
            comment_fingerprint: comment.export_fingerprint,
            position:
          )
        end
      end
    end
  end
end
