# frozen_string_literal: true

module PageFeedback
  # Abstract base class for engine-owned records in the host database.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
