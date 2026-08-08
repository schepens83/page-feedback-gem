# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "page_feedback"
require "generators/page_feedback/install_generator"

RSpec.describe PageFeedback::Generators::InstallGenerator do
  let(:destination_root) { Dir.mktmpdir("page-feedback-generator") }

  before { prepare_host }

  after { FileUtils.remove_entry(destination_root) }

  it "installs every host seam and reports actionable next steps", :aggregate_failures do
    expect { run_generator("--mount-path=/notes") }.to output(
      %r{open capture and review.*page_feedback:install:migrations.*/notes/review/pages}m
    ).to_stdout

    expect_installed
  end

  it "is idempotent when rerun", :aggregate_failures do
    run_generator
    paths = installed_paths
    first_contents = paths.index_with { |path| read(path) }

    run_generator

    expect_idempotent(paths, first_contents)
  end

  it "honors skip options" do
    run_generator("--skip-route", "--skip-layout", "--skip-stimulus")

    expect(read("config/routes.rb")).not_to include("PageFeedback")
    expect(read("app/views/layouts/application.html.erb")).not_to include("page_feedback_")
    expect(File).not_to exist(path("app/javascript/controllers/page_feedback_capture_controller.js"))
  end

  it "shows a customized file diff before a forced overwrite" do
    initializer = path("config/initializers/page_feedback.rb")
    FileUtils.mkdir_p(File.dirname(initializer))
    File.write(initializer, "# customized\n")

    expect { run_generator("--force", "--skip-route", "--skip-layout", "--skip-stimulus") }.to output(
      %r{--- config/initializers/page_feedback.rb.*- # customized.*\+ # frozen_string_literal: true}m
    ).to_stdout
    expect(read("config/initializers/page_feedback.rb")).to include("PageFeedback.configure")
  end

  it "reverses only generated files and insertions", :aggregate_failures do
    run_generator
    migration = path("db/migrate/20260808000001_create_page_feedback_comments.rb")
    FileUtils.mkdir_p(File.dirname(migration))
    File.write(migration, "# host-owned migration\n")

    run_generator(behavior: :revoke)

    expect_uninstalled(migration)
  end

  it "rejects external or query-bearing mount paths" do
    expect { run_generator("--mount-path=https://example.com") }.to raise_error(Thor::Error)
    expect { run_generator("--mount-path=/feedback?admin=1") }.to raise_error(Thor::Error)
  end

  private

  def run_generator(*arguments, behavior: :invoke)
    generator = described_class.new([], arguments, destination_root: destination_root, behavior: behavior)
    generator.invoke_all
  end

  def prepare_host
    FileUtils.mkdir_p(path("config"))
    FileUtils.mkdir_p(path("app/views/layouts"))
    File.write(path("config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    File.write(path("app/views/layouts/application.html.erb"), host_layout)
  end

  def host_layout
    [
      "<!DOCTYPE html>\n<html>\n  <head>\n  </head>\n",
      "  <body>\n    <%= yield %>\n  </body>\n</html>\n"
    ].join
  end

  def expect_installed
    expect_core_files_installed
    expect_proxies_installed
  end

  def expect_core_files_installed
    expect(read("config/initializers/page_feedback.rb")).to include("PageFeedback.configure", "open policies")
    expect(read("config/routes.rb")).to include('mount PageFeedback::Engine => "/notes"')
    expect(read("app/views/layouts/application.html.erb")).to include("page_feedback_head", "page_feedback_widget")
  end

  def expect_proxies_installed
    expect(read("app/javascript/controllers/page_feedback_capture_controller.js")).to include("capture_controller")
    expect(read("app/javascript/controllers/page_feedback_copy_controller.js")).to include("copy_controller")
  end

  def expect_idempotent(paths, first_contents)
    expect(paths.index_with { |path| read(path) }).to eq(first_contents)
    expect_single_injections
  end

  def expect_single_injections
    expect(read("config/routes.rb").scan("mount PageFeedback::Engine").size).to eq(1)
    expect(read("app/views/layouts/application.html.erb").scan("page_feedback_").size).to eq(2)
  end

  def expect_uninstalled(migration)
    expect(File).not_to exist(path("config/initializers/page_feedback.rb"))
    expect(File).not_to exist(path("app/javascript/controllers/page_feedback_capture_controller.js"))
    expect_injections_removed
    expect(File).to exist(migration)
  end

  def expect_injections_removed
    expect(read("config/routes.rb")).not_to include("PageFeedback")
    expect(read("app/views/layouts/application.html.erb")).not_to include("page_feedback_")
  end

  def installed_paths
    %w[
      config/initializers/page_feedback.rb
      config/routes.rb
      app/views/layouts/application.html.erb
      app/javascript/controllers/page_feedback_capture_controller.js
      app/javascript/controllers/page_feedback_copy_controller.js
    ]
  end

  def path(relative_path)
    File.join(destination_root, relative_path)
  end

  def read(relative_path)
    File.read(path(relative_path))
  end
end
