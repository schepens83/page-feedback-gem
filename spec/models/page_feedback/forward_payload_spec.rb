# frozen_string_literal: true

require "rails_helper"
require "zlib"

RSpec.describe PageFeedback::ForwardPayload do
  def decode(fragment)
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    JSON.parse(inflater.inflate(Base64.urlsafe_decode64(fragment.delete_prefix("pf2."))).force_encoding("UTF-8"))
  ensure
    inflater&.close
  end

  it "packs comments into a pf2 fragment that round-trips through the parser", :aggregate_failures do
    comment = create(:page_feedback_comment, comment_text: "Één klik te veel")
    fragment = described_class.fragment(comments: [comment], source: "Work laptop")

    expect(fragment).to match(/\Apf2\.[A-Za-z0-9_-]+\z/)
    payload = described_class.parse(JSON.generate(decode(fragment)))
    expect(payload).to include("format" => "page_feedback.forward", "version" => 1, "source" => "Work laptop")
    expect(payload["comments"].first).to include(
      "uuid" => comment.uuid, "comment_text" => "Één klik te veel", "page_path" => comment.page_path,
      "created_at" => comment.created_at.utc.iso8601
    )
  end

  it "rejects anything that is not a forward this version understands", :aggregate_failures do
    valid = { "format" => "page_feedback.forward", "version" => 1, "comments" => [{}] }

    expect { described_class.parse("") }.to raise_error(described_class::Invalid)
    expect { described_class.parse("{nope") }.to raise_error(described_class::Invalid, /JSON/)
    [{ "format" => "x" }, { "version" => 2 }, { "comments" => [] }].each do |change|
      expect { described_class.parse(JSON.generate(valid.merge(change))) }.to raise_error(described_class::Invalid)
    end
    expect { described_class.parse(JSON.generate(valid.merge("comments" => [{}] * 201))) }
      .to raise_error(described_class::Invalid, /200/)
    expect { described_class.parse("x" * (described_class::MAX_JSON_BYTES + 1)) }
      .to raise_error(described_class::Invalid, /large/)
  end
end
