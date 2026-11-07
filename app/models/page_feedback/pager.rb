# frozen_string_literal: true

module PageFeedback
  # Page-number arithmetic for a newest-first list. Lenient: a missing, invalid,
  # or out-of-range page number never raises, it lands on the nearest real page.
  class Pager
    DEFAULT_PER = 20

    # @return [Integer] the current, clamped, 1-based page
    attr_reader :page
    # @return [Integer] total number of pages (at least 1)
    attr_reader :pages
    # @return [Integer] records per page
    attr_reader :limit

    # @param page [String, Integer, nil] raw requested page
    # @param total [Integer] total record count
    # @param per [Integer] records per page
    def initialize(page:, total:, per: DEFAULT_PER)
      @limit = per
      @pages = [total.to_i.fdiv(per).ceil, 1].max
      @page = (parse(page) || 1).clamp(1, @pages)
    end

    # @return [Integer] rows to skip
    def offset
      (page - 1) * limit
    end

    # @return [Integer, nil] the previous page number, if any
    def newer_page
      page - 1 if page > 1
    end

    # @return [Integer, nil] the following page number, if any
    def older_page
      page + 1 if page < pages
    end

    # @return [Boolean] whether more than one page exists
    def paged?
      pages > 1
    end

    private

    def parse(raw)
      Integer(raw.to_s, 10) if raw.to_s.match?(/\A\d+\z/)
    end
  end
end
