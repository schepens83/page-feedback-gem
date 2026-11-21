# frozen_string_literal: true

require "page_feedback/host_updater/lockfile_diff"

RSpec.describe PageFeedback::HostUpdater::LockfileDiff do
  let(:headers) do
    "diff --git a/Gemfile.lock b/Gemfile.lock\nindex 1..2 100644\n--- a/Gemfile.lock\n+++ b/Gemfile.lock\n@@ -9 +9 @@\n"
  end

  it "allows the page_feedback revision, tag and version lines" do
    diff = headers + <<~DIFF
      -  revision: aaaa1111
      +  revision: bbbb2222
      -  tag: v0.2.0
      +  tag: v0.3.0
      -    page_feedback (0.2.0)
      +    page_feedback (0.3.0)
    DIFF
    expect(described_class.unexpected_lines(diff)).to be_empty
  end

  it "reports any other changed line" do
    diff = "#{headers}-    rails (8.0.1)\n+    rails (8.0.2)\n+  tag: v0.3.0\n"
    expect(described_class.unexpected_lines(diff)).to eq(["-    rails (8.0.1)", "+    rails (8.0.2)"])
  end

  it "treats an empty diff as clean" do
    expect(described_class.unexpected_lines("")).to be_empty
  end
end
