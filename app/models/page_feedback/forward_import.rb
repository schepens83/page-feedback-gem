# frozen_string_literal: true

module PageFeedback
  # Creates comments forwarded from another installation.
  #
  # Every comment is untrusted input held to capture's rules: the same
  # validations and limits, context normalized the same way, and no say over
  # review state, reviewer or submitter. A comment whose uuid already exists is
  # skipped, so importing the same forward twice changes nothing.
  class ForwardImport
    include PageFeedback::CommentContextNormalization

    # Outcome counts of one import.
    Result = Data.define(:source, :imported, :skipped, :invalid) do
      # @return [Integer]
      def total = imported.length + skipped + invalid
    end

    # Optional free-text fields copied as they are, length checks aside.
    OPTIONAL_TEXT_FIELDS = %i[refined_text page_title controller_action css_selector element_html].freeze

    # @param payload [Hash] a payload accepted by {ForwardPayload.parse}
    def initialize(payload)
      @payload = payload
    end

    # @return [Result]
    def call
      outcomes = @payload["comments"].map { |entry| import_one(entry) }
      imported = outcomes.grep(Comment)

      Result.new(source:, imported:, skipped: outcomes.count(:skipped), invalid: outcomes.count(:invalid))
    end

    private

    def source
      label(@payload["source"])
    end

    def import_one(entry)
      return :invalid unless entry.is_a?(Hash)

      uuid = entry["uuid"].to_s.downcase
      return :invalid unless Comment::UUID_PATTERN.match?(uuid)
      return :skipped if Comment.exists?(uuid:)

      comment = Comment.new(attributes(entry).merge(uuid:))
      comment.save ? comment : :invalid
    rescue ActiveRecord::RecordNotUnique
      :skipped
    end

    def attributes(entry)
      captured_attributes(entry).merge(
        category: category(entry["category"]),
        comment_text: entry["comment_text"].to_s,
        context: normalize_context(entry["context"]),
        origin: source,
        submitter_label: label(entry["submitter_label"]),
        created_at: captured_at(entry["created_at"])
      )
    end

    def captured_attributes(entry)
      OPTIONAL_TEXT_FIELDS.index_with do |field|
        entry[field.to_s].presence&.to_s
      end.merge(page_path: entry["page_path"].to_s)
    end

    def label(value)
      value.to_s.strip.presence&.truncate(Comment::MAX_LABEL_LENGTH)
    end

    def category(value)
      categories = PageFeedback.configuration.categories
      categories.key?(value) ? value : PageFeedback.configuration.default_category
    end

    def captured_at(value)
      [Time.iso8601(value.to_s), Time.current].min
    rescue ArgumentError
      Time.current
    end
  end
end
