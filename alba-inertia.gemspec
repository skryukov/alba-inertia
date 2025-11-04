# frozen_string_literal: true

require_relative "lib/alba/inertia/version"

Gem::Specification.new do |spec|
  spec.name = "alba-inertia"
  spec.version = Alba::Inertia::VERSION
  spec.authors = ["Svyatoslav Kryukov"]
  spec.email = ["me@skryukov.dev"]

  spec.summary = "Seamless integration between Alba and Inertia Rails."
  spec.description = "Seamless integration between Alba and Inertia Rails."
  spec.homepage = "https://github.com/skryukov/typelizer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "#{spec.homepage}/blob/main/README.md",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["{app,lib}/**/*", "CHANGELOG.md", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "alba"
  spec.add_dependency "inertia_rails"
  spec.add_dependency "zeitwerk"
end
