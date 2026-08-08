# frozen_string_literal: true

module PageFeedback
  # Read model for one page row in the review overview.
  class ReviewPage
    attr_reader :path, :key, :title, :newest_at, :counts, :categories

    # Build page rows for every distinct path represented by the filtered comments.
    #
    # @param comments [Enumerable<PageFeedback::Comment>]
    # @return [Array<PageFeedback::ReviewPage>]
    def self.from_comments(comments)
      paths = comments.map(&:page_path).uniq
      paths.map { |path| for_path(path) }.sort_by(&:newest_at).reverse
    end

    # Build a page row with counts calculated across all feedback on that path.
    #
    # @param path [String]
    # @return [PageFeedback::ReviewPage]
    def self.for_path(path)
      comments = Comment.where(page_path: path).includes(:export_items).recent.to_a
      new(path:, comments:)
    end

    # @param path [String]
    # @param comments [Array<PageFeedback::Comment>]
    def initialize(path:, comments:)
      newest = comments.first
      @path = path
      @key = Comment.page_key(path)
      @title = newest.page_title.presence || path
      @newest_at = newest.created_at
      @counts = count_states(comments)
      @categories = comments.map(&:category).tally
    end

    private

    def count_states(comments)
      {
        pending: comments.count(&:pending?),
        ready: comments.count(&:ready_for_export?),
        exported: comments.count { |comment| exported?(comment) },
        changed: comments.count { |comment| changed?(comment) },
        rejected: comments.count(&:rejected?)
      }
    end

    def exported?(comment)
      comment.approved? && comment.export_state == "exported"
    end

    def changed?(comment)
      comment.approved? && comment.export_state == "changed_since_export"
    end
  end
end
