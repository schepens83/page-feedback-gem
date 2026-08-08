# frozen_string_literal: true

require_relative "lib/page_feedback/version"

Gem::Specification.new do |spec|
  spec.name = "page_feedback"
  spec.version = PageFeedback::VERSION
  spec.authors = ["Sander Schepens"]
  spec.email = ["schepens@gmail.com"]

  spec.summary = "Capture, review, and export contextual feedback in Rails applications"
  spec.description = <<~DESCRIPTION
    An isolated Rails engine that captures element-level page feedback, supports
    in-context review, and creates immutable coding-agent-friendly exports.
  DESCRIPTION
  spec.homepage = "https://github.com/schepens83/page-feedback-gem"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2")
  spec.licenses = ["Nonstandard"]

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "#{spec.homepage}/blob/main/README.md",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "#{spec.homepage}/tree/main"
  }

  spec.files = Dir.chdir(__dir__) do
    patterns = ["{app,config,db,docs,exe,lib,sig}/**/*", "AGENTS.md", "CHANGELOG.md",
                "LICENSE.txt", "README.md"]
    Dir.glob(patterns, File::FNM_DOTMATCH).reject { |path| File.directory?(path) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.filter_map do |path|
    path.delete_prefix("exe/") if path.start_with?("exe/")
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "importmap-rails", ">= 2.0"
  spec.add_dependency "propshaft", ">= 1.0"
  spec.add_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_dependency "stimulus-rails", ">= 1.3"
  spec.add_dependency "turbo-rails", ">= 2.0"
end
