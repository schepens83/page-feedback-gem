# frozen_string_literal: true

require "rails_helper"
require "zlib"

RSpec.describe PageFeedback::Handoff do
  let(:base_url) { "https://example.test/feedback/review/handoff" }

  def unpack(parts)
    payload = parts.map { |part| part.url.split("#", 2).last.split(".", 5).last }.join
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    inflater.inflate(Base64.urlsafe_decode64(payload)).force_encoding(Encoding::UTF_8)
  ensure
    inflater&.close
  end

  it "packs a short body into one compressed code pointing at the unpack page" do
    parts = described_class.new("# Feedback\n\nLooks good.", base_url:).parts

    expect(parts.length).to eq(1)
    expect(parts.first.url).to match(%r{\Ahttps://example\.test/feedback/review/handoff#pf1\.[0-9a-f]{8}\.1\.1\.[A-Za-z0-9_-]+\z})
    expect(unpack(parts)).to eq("# Feedback\n\nLooks good.")
  end

  it "splits a large body into numbered parts sharing one id and round-trips UTF-8", :aggregate_failures do
    body = Array.new(120) { |i| "- Item #{i} — #{SecureRandom.hex(8)}" }.join("\n")
    parts = described_class.new(body, base_url:, chunk_size: 500).parts

    ids = parts.map { |part| part.url[/#pf1\.(\h{8})/, 1] }.uniq
    expect(parts.length).to be > 1
    expect(ids.length).to eq(1)
    expect(parts.map { |part| [part.index, part.total] }).to eq((1..parts.length).map { |i| [i, parts.length] })
    expect(unpack(parts)).to eq(body)
  end

  it "renders each part as an SVG QR code" do
    part = described_class.new("Short", base_url:).parts.first

    expect(part.svg).to start_with("<?xml").and include("<svg")
  end

  it "refuses bodies that would need more codes than anyone wants to scan" do
    body = SecureRandom.alphanumeric(40_000)
    handoff = described_class.new(body, base_url:)

    expect(handoff).not_to be_fits
    expect(handoff.parts).to eq([])
  end
end
