# frozen_string_literal: true

require "base64"
require "digest"
require "rqrcode"
require "zlib"

module PageFeedback
  # Packs an export body into QR codes a phone can scan off a screen.
  #
  # A host that runs offline (no network path to where the feedback is acted
  # on) can still hand an export over: the body is raw-deflated, base64url
  # encoded and split into parts. Each part is a URL to the review handoff page
  # of a host the phone can reach, with the data in the fragment, which browsers
  # never send to the server. The page reassembles the parts and inflates them.
  #
  # Fragment format: +pf1.<id>.<index>.<total>.<chunk>+, where +id+ is the first
  # eight hex digits of the SHA-256 of the whole payload.
  class Handoff
    # Fragment format marker, bumped if the encoding ever changes.
    FORMAT = "pf1"
    # Base64url characters per code. 700 gives a 93-module code that decoded
    # reliably off a screen at 100-150% display scaling; 1,000 (109 modules)
    # did not.
    CHUNK_SIZE = 700
    # More codes than this and downloading the Markdown is the better route.
    MAX_PARTS = 12

    # One scannable code.
    Part = Data.define(:url, :index, :total) do
      # A fixed size (4px per module, 16px white quiet zone) rather than a
      # scalable viewBox: a fractional pixel per module blurs the code.
      #
      # @return [String] the QR code as a standalone SVG document
      def svg
        RQRCode::QRCode.new(url, level: :l)
                       .as_svg(module_size: 4, offset: 16, use_path: true, color: "000", fill: "fff")
      end
    end

    # @param body [String] Markdown to hand over
    # @param base_url [String] absolute URL of a reachable handoff page
    # @param chunk_size [Integer] payload characters per code
    def initialize(body, base_url:, chunk_size: CHUNK_SIZE)
      @body = body.to_s
      @base_url = base_url
      @chunk_size = chunk_size
    end

    # @return [Boolean] whether the body fits in {MAX_PARTS} codes
    def fits?
      chunks.length <= MAX_PARTS
    end

    # @return [Array<Part>] the codes in scan order, empty when it does not fit
    def parts
      return [] unless fits?

      total = chunks.length
      chunks.each_with_index.map do |chunk, offset|
        index = offset + 1
        Part.new(url: "#{@base_url}##{FORMAT}.#{id}.#{index}.#{total}.#{chunk}", index:, total:)
      end
    end

    private

    def id
      Digest::SHA256.hexdigest(payload)[0, 8]
    end

    def chunks
      @chunks ||= payload.scan(/.{1,#{@chunk_size}}/)
    end

    def payload
      @payload ||= Base64.urlsafe_encode64(deflate(@body), padding: false)
    end

    def deflate(text)
      deflater = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
      deflater.deflate(text.b, Zlib::FINISH)
    ensure
      deflater&.close
    end
  end
end
