# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/file_updaters/java_script/npm"
require_relative "../shared_examples_for_file_updaters"

RSpec.describe Dependabot::FileUpdaters::JavaScript::Npm do
  it_behaves_like "a dependency file updater"

  let(:updater) do
    described_class.new(
      dependency_files: files,
      dependencies: [dependency],
      credentials: [
        {
          "host" => "github.com",
          "username" => "x-access-token",
          "password" => "token"
        }
      ]
    )
  end
  let(:files) { [package_json, lockfile] }
  let(:package_json) do
    Dependabot::DependencyFile.new(
      content: package_json_body,
      name: "package.json"
    )
  end
  let(:package_json_body) do
    fixture("javascript", "package_files", "package.json")
  end
  let(:lockfile) do
    Dependabot::DependencyFile.new(
      name: "package-lock.json",
      content: fixture("javascript", "npm_lockfiles", "package-lock.json")
    )
  end
  let(:dependency) do
    Dependabot::Dependency.new(
      name: "fetch-factory",
      version: "0.0.2",
      package_manager: "npm",
      requirements: [
        { file: "package.json", requirement: "^0.0.1", groups: [], source: nil }
      ]
    )
  end
  let(:tmp_path) { Dependabot::SharedHelpers::BUMP_TMP_DIR_PATH }

  before { Dir.mkdir(tmp_path) unless Dir.exist?(tmp_path) }

  describe "#updated_dependency_files" do
    subject(:updated_files) { updater.updated_dependency_files }

    it "doesn't store the files permanently" do
      expect { updated_files }.to_not(change { Dir.entries(tmp_path) })
    end

    it "returns DependencyFile objects" do
      updated_files.each { |f| expect(f).to be_a(Dependabot::DependencyFile) }
    end

    specify { expect { updated_files }.to_not output.to_stdout }
    its(:length) { is_expected.to eq(2) }

    describe "the updated package_json_file" do
      subject(:updated_package_json_file) do
        updated_files.find { |f| f.name == "package.json" }
      end

      its(:content) { is_expected.to include "{{ name }}" }
      its(:content) { is_expected.to include "\"fetch-factory\": \"^0.0.2\"" }
      its(:content) { is_expected.to include "\"etag\": \"^1.0.0\"" }

      context "when the minor version is specified" do
        let(:dependency) do
          Dependabot::Dependency.new(
            name: "fetch-factory",
            version: "0.2.1",
            package_manager: "npm",
            requirements: [
              {
                file: "package.json",
                requirement: "^0.0.1",
                groups: [],
                source: nil
              }
            ]
          )
        end
        let(:package_json_body) do
          fixture("javascript", "package_files", "minor_version_specified.json")
        end

        its(:content) { is_expected.to include "\"fetch-factory\": \"0.2.x\"" }
      end

      context "with a path-based dependency" do
        let(:files) { [package_json, lockfile, path_dep] }
        let(:package_json_body) do
          fixture("javascript", "package_files", "path_dependency.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "path_dependency.json")
        end
        let(:path_dep) do
          Dependabot::DependencyFile.new(
            name: "deps/etag/package.json",
            content: fixture("javascript", "package_files", "etag.json")
          )
        end
        let(:dependency) do
          Dependabot::Dependency.new(
            name: "lodash",
            version: "1.3.1",
            package_manager: "npm",
            requirements: [
              {
                file: "package.json",
                requirement: "^1.2.1",
                groups: [],
                source: nil
              }
            ]
          )
        end

        its(:content) { is_expected.to include "\"lodash\": \"^1.3.1\"" }
        its(:content) do
          is_expected.to include "\"etag\": \"file:./deps/etag\""
        end
      end
    end

    describe "the updated lockfile" do
      subject(:updated_lockfile) do
        updated_files.find { |f| f.name == "package-lock.json" }
      end

      it "has details of the updated item" do
        parsed_lockfile = JSON.parse(updated_lockfile.content)
        expect(parsed_lockfile["dependencies"]["fetch-factory"]["version"]).
          to eq("0.0.2")
      end

      context "with a path-based dependency" do
        let(:files) { [package_json, lockfile, path_dep] }
        let(:package_json_body) do
          fixture("javascript", "package_files", "path_dependency.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "path_dependency.json")
        end
        let(:path_dep) do
          Dependabot::DependencyFile.new(
            name: "deps/etag/package.json",
            content: fixture("javascript", "package_files", "etag.json")
          )
        end
        let(:dependency) do
          Dependabot::Dependency.new(
            name: "lodash",
            version: "1.3.1",
            package_manager: "npm",
            requirements: [
              {
                file: "package.json",
                requirement: "^1.2.1",
                groups: [],
                source: nil
              }
            ]
          )
        end

        it "has details of the updated item" do
          parsed_lockfile = JSON.parse(updated_lockfile.content)
          expect(parsed_lockfile["dependencies"]["lodash"]["version"]).
            to eq("1.3.1")
        end
      end
    end
  end
end
