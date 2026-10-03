# frozen_string_literal: true

require "fileutils"
require "open3"
require "page_feedback/host_updater"
require "tmpdir"

RSpec.describe PageFeedback::HostUpdater do
  let(:hosts_dir) { Dir.mktmpdir("hosts") }

  after { FileUtils.remove_entry(hosts_dir) }

  def make_host(name, gemfile)
    dir = File.join(hosts_dir, name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "Gemfile"), gemfile)
    system("git", "-C", dir, "init", "-q", exception: true)
    system("git", "-C", dir, "config", "user.email", "host@example.test", exception: true)
    system("git", "-C", dir, "config", "user.name", "Host", exception: true)
    system("git", "-C", dir, "add", ".", exception: true)
    system("git", "-C", dir, "commit", "-qm", "initial", exception: true)
    dir
  end

  def update(dir, calls = [], **options)
    runner = options.delete(:runner) || successful_runner(calls)
    described_class.new(version: "0.1.2", roots: [dir], runner: runner, **options).call
  end

  def successful_runner(calls = [])
    lambda do |command, chdir:|
      calls << [chdir, command]
      ["", "", Struct.new(:success?).new(true)]
    end
  end

  def status_runner(porcelain_output = "")
    lambda do |command, **|
      if command.include?("--porcelain")
        [porcelain_output, "", Struct.new(:success?).new(true)]
      else
        ["", "", Struct.new(:success?).new(true)]
      end
    end
  end

  def failing_runner(message)
    lambda do |command, **|
      if command[0] == "bundle"
        ["", message, Struct.new(:success?).new(false)]
      else
        ["", "", Struct.new(:success?).new(true)]
      end
    end
  end

  it "bumps a single-line single-quoted tag preserving the quote style" do
    dir = make_host("picturescraps", "gem 'page_feedback', github: 'x/y', tag: 'v0.1.1'\n")
    calls = []
    report = update(dir, calls)
    expect(report.first.status).to eq(:updated)
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: 'v0.1.2'")
    expect(calls.map(&:last)).to include(
      %w[bundle update page_feedback],
      ["git", "-C", dir, "add", "Gemfile", "Gemfile.lock"],
      ["git", "-C", dir, "commit", "-m", "Bump page_feedback to v0.1.2"]
    )
  end

  it "bumps a multi-line double-quoted tag on its own line" do
    dir = make_host("duitdoktor", <<~GEMFILE)
      source "https://rubygems.org"
      gem "page_feedback",
        git: "https://github.com/schepens83/page-feedback-gem.git",
        tag: "v0.1.1"
    GEMFILE
    report = update(dir)
    expect(report.first.status).to eq(:updated)
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: \"v0.1.2\"")
  end

  it "bumps a declaration whose tag sits on the following line" do
    dir = make_host("schepens.cc", <<~GEMFILE)
      gem "page_feedback", github: "schepens83/page-feedback-gem",
                           tag: "v0.1.1"
    GEMFILE
    report = update(dir)
    expect(report.first.status).to eq(:updated)
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: \"v0.1.2\"")
  end

  it "leaves an already-current host alone" do
    dir = make_host("current", "gem 'page_feedback', github: 'x/y', tag: 'v0.1.2'\n")
    calls = []
    report = update(dir, calls)
    expect(report.first.status).to eq(:up_to_date)
    expect(calls).to be_empty
  end

  it "skips commit-pinned declarations without rewriting them" do
    dir = make_host("adoption", <<~GEMFILE)
      gem "page_feedback",
        git: "https://github.com/schepens83/page-feedback-gem.git",
        ref: "a459ac49ec900e78627bc1eb7b6db9a83c6be227"
    GEMFILE
    report = update(dir)
    expect(report.first.status).to eq(:ref_pin)
    expect(File.read(File.join(dir, "Gemfile"))).to include("ref:")
  end

  it "skips branch-pinned declarations" do
    dir = make_host("branch", "gem 'page_feedback', github: 'x/y', branch: 'main'\n")
    report = update(dir)
    expect(report.first.status).to eq(:branch_pin)
  end

  it "skips hosts with a dirty worktree without touching anything" do
    dir = make_host("dirty", "gem 'page_feedback', github: 'x/y', tag: 'v0.1.1'\n")
    File.write(File.join(dir, "notes.txt"), "uncommitted\n")
    report = update(dir, runner: status_runner("?? notes.txt\n"))
    expect(report.first.status).to eq(:dirty)
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: 'v0.1.1'")
  end

  it "reports a dry run without writing or running anything" do
    dir = make_host("picturescraps", "gem 'page_feedback', github: 'x/y', tag: 'v0.1.1'\n")
    calls = []
    report = update(dir, calls, dry_run: true)
    expect(report.first.status).to eq(:would_update)
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: 'v0.1.1'")
    expect(calls.map(&:last)).to eq([["git", "-C", dir, "status", "--porcelain"]])
  end

  it "restores the Gemfile when the dependency refresh fails" do
    dir = make_host("broken", "gem 'page_feedback', github: 'x/y', tag: 'v0.1.1'\n")
    report = update(dir, runner: failing_runner("no such gem"))
    expect(report.first.status).to eq(:failed)
    expect(report.first.detail).to include("no such gem")
    expect(File.read(File.join(dir, "Gemfile"))).to include("tag: 'v0.1.1'")
  end

  it "uses the default host root glob when no roots are given" do
    expect(described_class).to respond_to(:default_roots)
    expect(described_class.default_roots).to be_a(Array)
  end
end
