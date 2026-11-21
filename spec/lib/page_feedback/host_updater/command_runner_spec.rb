# frozen_string_literal: true

require "page_feedback/host_updater/command_runner"
require "tmpdir"

RSpec.describe PageFeedback::HostUpdater::CommandRunner do
  describe "#wrap" do
    it "runs bundler and ruby commands through mise in the host directory" do
      runner = described_class.new(mise: true)
      expect(runner.wrap(%w[bundle install], "/host")).to eq(%w[mise x -C /host -- bundle install])
    end

    it "runs git directly" do
      runner = described_class.new(mise: true)
      expect(runner.wrap(%w[git status], "/host")).to eq(%w[git status])
    end

    it "runs commands directly when mise is unavailable" do
      runner = described_class.new(mise: false)
      expect(runner.wrap(%w[bundle install], "/host")).to eq(%w[bundle install])
    end
  end

  describe "#environment" do
    it "unsets inherited Ruby and Bundler variables" do
      caller_env = { "RUBYOPT" => "-w", "GEM_HOME" => "/g", "BUNDLE_GEMFILE" => "/x", "BUNDLER_VERSION" => "2",
                     "BUNDLE_WITHOUT" => "test", "HOME" => "/home/x" }
      env = described_class.new(mise: false, inherited: caller_env).environment
      expect(env.keys).to include("BUNDLE_WITHOUT", *described_class::SCRUBBED)
      expect(env.keys).not_to include("HOME")
      expect(env.values.uniq).to eq([nil])
    end
  end

  describe "#call" do
    it "does not leak the caller's RUBYOPT to the command" do
      original = ENV.fetch("RUBYOPT", nil)
      ENV["RUBYOPT"] = "-w"
      runner = described_class.new(mise: false)
      out, _err, status = runner.call(["sh", "-c", "printf %s \"$RUBYOPT\""], chdir: Dir.tmpdir)
      expect([out, status.success?]).to eq(["", true])
    ensure
      ENV["RUBYOPT"] = original
    end
  end
end
