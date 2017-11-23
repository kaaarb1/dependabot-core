# frozen_string_literal: true

require "dependabot/file_fetchers/java_script/yarn"
require_relative "../shared_examples_for_file_fetchers"

RSpec.describe Dependabot::FileFetchers::JavaScript::Yarn do
  it_behaves_like "a dependency file fetcher"

  let(:source) { { host: "github", repo: "gocardless/bump" } }
  let(:file_fetcher_instance) do
    described_class.new(source: source, credentials: credentials)
  end
  let(:url) { "https://api.github.com/repos/gocardless/bump/contents/" }
  let(:credentials) do
    [
      {
        "host" => "github.com",
        "username" => "x-access-token",
        "password" => "token"
      }
    ]
  end

  context "with a path dependency" do
    before do
      allow(file_fetcher_instance).to receive(:commit).and_return("sha")

      stub_request(:get, url + "package.json?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_json_with_path_content.json"),
          headers: { "content-type" => "application/json" }
        )

      stub_request(:get, url + "yarn.lock?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "yarn_lock_content.json"),
          headers: { "content-type" => "application/json" }
        )
    end

    context "with a bad package.json" do
      before do
        stub_request(:get, url + "package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "gemfile_content.json"),
            headers: { "content-type" => "application/json" }
          )
      end

      it "raises a DependencyFileNotParseable error" do
        expect { file_fetcher_instance.files }.
          to raise_error(Dependabot::DependencyFileNotParseable) do |error|
            expect(error.file_name).to eq("package.json")
          end
      end
    end

    context "that has a fetchable path" do
      before do
        stub_request(:get, url + "deps/etag/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
      end

      it "fetches package.json from path dependency" do
        expect(file_fetcher_instance.files.count).to eq(3)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("deps/etag/package.json")
      end
    end

    context "that has an unfetchable path" do
      before do
        stub_request(:get, url + "deps/etag/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
      end

      it "raises a PathDependenciesNotReachable error with details" do
        expect { file_fetcher_instance.files }.
          to raise_error(
            Dependabot::PathDependenciesNotReachable,
            "The following path based dependencies could not be retrieved: " \
            "etag"
          )
      end
    end
  end

  context "with worspaces" do
    before do
      allow(file_fetcher_instance).to receive(:commit).and_return("sha")

      stub_request(:get, url + "package.json?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_json_with_workspaces_content.json"),
          headers: { "content-type" => "application/json" }
        )

      stub_request(:get, url + "yarn.lock?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "yarn_lock_content.json"),
          headers: { "content-type" => "application/json" }
        )
    end

    context "that have fetchable paths" do
      before do
        stub_request(:get, url + "packages?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "packages/package1/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "packages/package2/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "other_package/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
      end

      it "fetches package.json from path dependency" do
        expect(file_fetcher_instance.files.count).to eq(5)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("packages/package2/package.json")
      end
    end

    context "that has an unfetchable path" do
      before do
        stub_request(:get, url + "packages?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "packages/package1/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "packages/package2/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
        stub_request(:get, url + "other_package/package.json?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 404,
            body: fixture("github", "package_json_content.json"),
            headers: { "content-type" => "application/json" }
          )
      end

      it "raises a PathDependenciesNotReachable error with details" do
        expect { file_fetcher_instance.files }.
          to raise_error(
            Dependabot::PathDependenciesNotReachable,
            "The following path based dependencies could not be retrieved: " \
            "/other_package/package.json"
          )
      end
    end
  end
end
