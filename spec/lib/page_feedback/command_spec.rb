# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "page_feedback/command"

RSpec.describe PageFeedback::Command do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  it "ships successful help, docs, and version commands", :aggregate_failures do
    %w[--help docs version].each do |command|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, command)

      expect(status).to be_success
      expect(stdout).not_to be_empty
      expect(stderr).to be_empty
    end
  end

  it "documents every command, JSON option, generated seam, and authorization warning" do
    status = described_class.run(["help"], out: out, err: err)

    expect(status).to eq(0)
    expect(out.string).to include(
      "doctor [--json]", "docs", "version", "initializer", "engine mount",
      "layout helpers", "Stimulus proxy controllers", "authorization are open"
    )
  end

  it "renders doctor JSON and returns success when checks only pass or warn" do
    report = diagnostic_report("warn")
    status = run_doctor(report, "--json")

    expect(status).to eq(0)
    expect(JSON.parse(out.string)).to include("version" => PageFeedback::VERSION, "ok" => true)
    expect(err.string).to be_empty
  end

  it "returns failure when doctor finds a required integration failure" do
    status = run_doctor(diagnostic_report("fail"))

    expect(status).to eq(1)
    expect(out.string).to include("FAIL", "Required integration")
  end

  it "fails clearly outside a Rails application" do
    status = described_class.run(["doctor"], out: out, err: err, cwd: "/not/a/rails/app")

    expect(status).to eq(1)
    expect(err.string).to include("Rails application not found")
  end

  private

  def executable
    File.expand_path("../../../exe/page_feedback", __dir__)
  end

  def run_doctor(report, *arguments)
    options = {
      out: out, err: err, environment_loader: -> {},
      diagnostics_factory: -> { double(call: report) }
    }
    described_class.run(["doctor", *arguments], **options)
  end

  def diagnostic_report(status)
    check = PageFeedback::Diagnostics::Check.new(
      name: "fixture", label: "Required integration", status: status, details: "fixture"
    )
    PageFeedback::Diagnostics::Report.new(
      version: PageFeedback::VERSION, rails_version: Rails.version, checks: [check],
      review_path: "http://localhost:3000/feedback/review/pages", docs_path: "/gem/docs"
    )
  end
end
