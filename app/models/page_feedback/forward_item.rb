# frozen_string_literal: true

module PageFeedback
  # Immutable membership of one comment in one forward.
  class ForwardItem < ApplicationRecord
    belongs_to :forward, class_name: "PageFeedback::Forward", inverse_of: :forward_items
    belongs_to :comment, class_name: "PageFeedback::Comment", inverse_of: :forward_items

    validates :comment_id, uniqueness: { scope: :forward_id }

    # Persisted membership cannot be changed or removed.
    #
    # @return [Boolean]
    def readonly?
      persisted? || super
    end
  end
end
