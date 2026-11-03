# frozen_string_literal: true

require "base64"
require "json"
require "zlib"

module PageFeedback
  # The wire format that carries comments from one installation of a host app
  # to another inside a URL fragment (see docs/WORKFLOW.md, "Forwarding").
  #
  # A fragment is +pf2.+ followed by base64url (unpadded) of raw-deflated UTF-8
  # JSON. The receiving browser inflates it and posts the JSON to the import
  # endpoint; the server never sees the fragment itself.
  module ForwardPayload
    # Raised when posted JSON is not a forward payload this version understands.
    class Invalid < StandardError; end

    # Fragment prefix, bumped if the encoding ever changes.
    PREFIX = "pf2"
    # Value of the payload's +format+ key.
    FORMAT = "page_feedback.forward"
    # Value of the payload's +version+ key.
    VERSION = 1
    # Most comments one forward carries; larger selections are split.
    MAX_COMMENTS = 200
    # Largest JSON body the import endpoint accepts.
    MAX_JSON_BYTES = 3_000_000
    # Comment attributes that travel between installations.
    FIELDS = %w[
      uuid category comment_text refined_text page_path page_title
      controller_action css_selector element_html context
    ].freeze

    module_function

    # @param comments [Enumerable<PageFeedback::Comment>]
    # @param source [String] how the sending installation names itself
    # @return [Hash] the JSON-ready payload
    def build(comments:, source:)
      {
        "format" => FORMAT,
        "version" => VERSION,
        "source" => source,
        "comments" => comments.map { |comment| comment_hash(comment) }
      }
    end

    # @param comments [Enumerable<PageFeedback::Comment>]
    # @param source [String]
    # @return [String] the URL fragment, without the leading +#+
    def fragment(comments:, source:)
      json = JSON.generate(build(comments:, source:))
      "#{PREFIX}.#{Base64.urlsafe_encode64(deflate(json), padding: false)}"
    end

    # @param comment [PageFeedback::Comment]
    # @return [Hash]
    def comment_hash(comment)
      FIELDS.index_with { |field| comment.public_send(field) }.merge(
        "created_at" => comment.created_at&.utc&.iso8601,
        "submitter_label" => comment.submitter_display_label
      )
    end

    # @param json [String] the decoded payload posted by the handoff page
    # @return [Hash] with "source" (String, nil) and "comments" (Array<Hash>)
    # @raise [Invalid]
    def parse(json)
      raise Invalid, "payload is missing" if json.blank?
      raise Invalid, "payload is too large" if json.bytesize > MAX_JSON_BYTES

      payload = JSON.parse(json)
      validate!(payload)
      payload
    rescue JSON::ParserError
      raise Invalid, "payload is not JSON"
    end

    # @param payload [Object]
    # @raise [Invalid]
    def validate!(payload)
      raise Invalid, "payload is not an object" unless payload.is_a?(Hash)
      raise Invalid, "not a page feedback forward" unless payload["format"] == FORMAT
      raise Invalid, "unsupported version #{payload['version'].inspect}" unless payload["version"] == VERSION

      comments = payload["comments"]
      raise Invalid, "comments are missing" unless comments.is_a?(Array) && comments.any?
      raise Invalid, "more than #{MAX_COMMENTS} comments" if comments.length > MAX_COMMENTS
    end

    def deflate(text)
      deflater = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
      deflater.deflate(text.b, Zlib::FINISH)
    ensure
      deflater&.close
    end
    private_class_method :deflate
  end
end
