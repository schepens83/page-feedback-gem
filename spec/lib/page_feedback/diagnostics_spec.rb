# frozen_string_literal: true

require "rails_helper"
require "fileutils"
require "json"
require "tmpdir"

RSpec.describe PageFeedback::Diagnostics do
  let(:host_root) { Pathname(Dir.mktmpdir("page-feedback-doctor")) }
  let(:configuration) { PageFeedback::Configuration.new }
  let(:options) { {} }
  let(:diagnostics) do
    described_class.new(application: Rails.application, root: host_root,
                        configuration: configuration, **options)
  end

  before { prepare_installed_host }

  after { FileUtils.remove_entry(host_root) }

  it "reports a complete install as successful while warning about open authorization" do
    report = diagnostics.call

    expect(report).to be_ok
    expect(status_for(report, "open_authorization")).to eq("warn")
    expect(report.to_text).to include(
      "PageFeedback #{PageFeedback::VERSION}", "Engine mounted at /feedback",
      "WARN  Authorization is open", "Review: http://localhost:3000/feedback/review/pages"
    )
  end

  it "has a stable JSON schema whose warnings do not fail the run", :aggregate_failures do
    payload = JSON.parse(diagnostics.call.to_json)

    expect(payload.keys).to eq(%w[version ok checks])
    expect(payload.fetch("ok")).to be(true)
    expect(payload.fetch("checks").first.keys).to eq(%w[name status details])
    expect(payload.fetch("checks").map { |check| check.fetch("name") }).to eq(expected_check_names)
  end

  broken_host_cases = {
    "engine_mount" => -> { allow(Rails.application.routes).to receive(:routes).and_return([]) },
    "initializer" => -> { FileUtils.rm_f(host_root.join("config/initializers/page_feedback.rb")) },
    "configuration_callbacks" => -> { configuration.current_actor = nil },
    "migrations_installed" => -> { FileUtils.rm_f(host_root.glob("db/migrate/*comments*.rb").first) },
    "layout_helpers" => -> { host_root.join("app/views/layouts/application.html.erb").write("<html></html>\n") },
    "stimulus_proxy" => lambda do
      FileUtils.rm_f(host_root.join("app/javascript/controllers/page_feedback_capture_controller.js"))
    end,
    "default_category" => -> { configuration.default_category = "missing" },
    "export_formatter" => -> { configuration.export_formatter = ->(**) {} }
  }.freeze

  broken_host_cases.each do |check_name, break_fixture|
    it "detects a broken #{check_name} fixture" do
      instance_exec(&break_fixture)

      expect(status_for(diagnostics.call, check_name)).to eq("fail")
    end
  end

  it "detects pending migrations" do
    options[:migration_context] = Struct.new(:needs_migration?).new(true)

    expect(status_for(diagnostics.call, "migrations_pending")).to eq("fail")
  end

  it "detects a missing database table" do
    options[:connection] = Class.new do
      def data_source_exists?(table)
        table != "page_feedback_exports"
      end
    end.new

    expect(status_for(diagnostics.call, "tables")).to eq("fail")
  end

  it "detects missing or unsupported dependencies" do
    options[:gem_registry] = Gem.loaded_specs.except("propshaft")

    expect(status_for(diagnostics.call, "dependencies")).to eq("fail")
  end

  it "detects an unsupported Rails version" do
    options[:rails_version] = "7.2.0"

    expect(status_for(diagnostics.call, "rails_version")).to eq("fail")
  end

  it "detects unresolvable assets" do
    load_path = instance_double(Propshaft::LoadPath, find: nil)
    allow(Rails.application).to receive(:assets).and_return(instance_double(Propshaft::Assembly, load_path: load_path))

    expect(status_for(diagnostics.call, "assets")).to eq("fail")
  end

  it "detects missing packaged documentation" do
    options[:engine_root] = host_root.join("missing-engine")

    expect(status_for(diagnostics.call, "documentation")).to eq("fail")
  end

  private

  def prepare_installed_host
    write("config/initializers/page_feedback.rb", "# installed\n")
    write("app/views/layouts/application.html.erb", "<%= page_feedback_head %>\n<%= page_feedback_widget %>\n")
    write("app/javascript/controllers/page_feedback_capture_controller.js", "// installed\n")
    write("app/javascript/controllers/page_feedback_copy_controller.js", "// installed\n")
    PageFeedback::Engine.root.glob("db/migrate/*.rb").each_with_index do |migration, index|
      name = migration.basename(".rb").to_s.sub(/\A\d+_/, "")
      write("db/migrate/2026080815000#{index}_#{name}.page_feedback.rb", migration.read)
    end
  end

  def write(relative_path, contents)
    path = host_root.join(relative_path)
    path.dirname.mkpath
    path.write(contents)
  end

  def status_for(report, name)
    report.checks.find { |check| check.name == name }.status
  end

  def expected_check_names
    %w[
      gem_version rails_version dependencies engine_mount initializer
      configuration_callbacks open_authorization migrations_installed
      migrations_pending tables layout_helpers stimulus_proxy assets
      default_category export_formatter documentation
    ]
  end
end
