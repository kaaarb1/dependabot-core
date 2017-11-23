# frozen_string_literal: true

require "dependabot/file_fetchers/base"
require "dependabot/file_parsers/java_script/yarn"

module Dependabot
  module FileFetchers
    module JavaScript
      class Yarn < Dependabot::FileFetchers::Base
        def self.required_files_in?(filenames)
          (%w(package.json yarn.lock) - filenames).empty?
        end

        def self.required_files_message
          "Repo must contain a package.json and a yarn.lock."
        end

        private

        def fetch_files
          fetched_files = []
          fetched_files << package_json
          fetched_files << yarn_lock
          fetched_files += path_dependencies
          fetched_files += workspace_package_jsons
          fetched_files
        end

        def package_json
          @package_json ||= fetch_file_from_github("package.json")
        end

        def yarn_lock
          @yarn_lock ||= fetch_file_from_github("yarn.lock")
        end

        def path_dependencies
          package_json_files = []
          unfetchable_deps = []

          types = Dependabot::FileParsers::JavaScript::Yarn::DEPENDENCY_TYPES
          parsed_package_json.values_at(*types).compact.each do |deps|
            deps.map do |name, version|
              next unless version.start_with?("file:")

              path = version.sub(/^file:/, "")
              file = File.join(path, "package.json")

              begin
                package_json_files << fetch_file_from_github(file)
              rescue Dependabot::DependencyFileNotFound
                unfetchable_deps << name
              end
            end
          end

          if unfetchable_deps.any?
            raise Dependabot::PathDependenciesNotReachable, unfetchable_deps
          end

          package_json_files
        end

        def workspace_package_jsons
          return [] unless parsed_package_json["workspaces"]
          package_json_files = []
          unfetchable_deps = []

          parsed_package_json["workspaces"].each do |path|
            workspaces =
              if path.end_with?("*") then expand_workspaces(path)
              else [Pathname.new(File.join(directory, path)).cleanpath.to_path]
              end

            workspaces.each do |workspace|
              file = File.join(workspace, "package.json")

              begin
                package_json_files << fetch_file_from_github(file)
              rescue Dependabot::DependencyFileNotFound
                unfetchable_deps << file
              end
            end
          end

          if unfetchable_deps.any?
            raise Dependabot::PathDependenciesNotReachable, unfetchable_deps
          end

          package_json_files
        end

        def expand_workspaces(path)
          path = File.join(directory, path.gsub(/\*$/, ""))
          path = Pathname.new(path).cleanpath.to_path
          github_client.contents(repo, path: path, ref: commit).
            select { |file| file.type == "dir" }.
            map(&:path)
        end

        def parsed_package_json
          JSON.parse(package_json.content)
        rescue JSON::ParserError
          raise Dependabot::DependencyFileNotParseable, package_json.path
        end
      end
    end
  end
end
