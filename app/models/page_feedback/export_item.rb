# frozen_string_literal: true

module PageFeedback
  # Immutable membership of one comment revision in one export snapshot.
  class ExportItem < ApplicationRecord
    belongs_to :export, class_name: "PageFeedback::Export", inverse_of: :export_items
    belongs_to :comment, class_name: "PageFeedback::Comment", inverse_of: :export_items

    validates :comment_fingerprint, presence: true
    validates :comment_id, uniqueness: { scope: :export_id }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Persisted membership cannot be changed or removed.
    #
    # @return [Boolean]
    def readonly?
      persisted? || super
    end
  end
end
