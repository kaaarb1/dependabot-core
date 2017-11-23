# frozen_string_literal: true

require "excon"
require "dependabot/update_checkers/base"
require "dependabot/shared_helpers"

require "json"

module Dependabot
  module UpdateCheckers
    module Php
      class Composer < Dependabot::UpdateCheckers::Base
        def latest_version
          # Fall back to latest_resolvable_version if no listing on main
          # registry.
          # TODO: Check against all repositories, if alternatives are specified
          return latest_resolvable_version unless packagist_listing

          versions =
            packagist_listing["packages"][dependency.name].
            keys.map do |version|
              begin
                Gem::Version.new(version)
              rescue ArgumentError
                nil
              end
            end.compact

          versions.reject(&:prerelease?).sort.last
        end

        def latest_resolvable_version
          @latest_resolvable_version ||= fetch_latest_resolvable_version
        end

        def updated_requirements
          return dependency.requirements unless latest_resolvable_version

          version_regex = /[0-9]+(?:\.[a-zA-Z0-9]+)*/
          updated_requirement =
            dependency.requirements.first[:requirement].
            sub(version_regex) do |old_version|
              precision = old_version.split(".").count
              latest_resolvable_version.to_s.
                split(".").
                first(precision).
                join(".")
            end

          [
            dependency.requirements.first.
              merge(requirement: updated_requirement)
          ]
        end

        private

        def latest_version_resolvable_with_full_unlock?
          # Full unlock checks aren't implemented for Composer (yet)
          false
        end

        def updated_dependencies_after_full_unlock
          raise NotImplementedError
        end

        def fetch_latest_resolvable_version
          latest_resolvable_version =
            SharedHelpers.in_a_temporary_directory do
              File.write("composer.json", composer_file.content)
              File.write("composer.lock", lockfile.content)

              SharedHelpers.run_helper_subprocess(
                command: "php #{php_helper_path}",
                function: "get_latest_resolvable_version",
                args: [Dir.pwd, dependency.name]
              )
            end

          if latest_resolvable_version.nil?
            nil
          else
            Gem::Version.new(latest_resolvable_version)
          end
        rescue SharedHelpers::HelperSubprocessFailed
          # TODO: We shouldn't be suppressing these errors but they're caused
          # by memory issues that we don't currently have a solution to.
          nil
        end

        def composer_file
          composer_file =
            dependency_files.find { |f| f.name == "composer.json" }
          raise "No composer.json!" unless composer_file
          composer_file
        end

        def lockfile
          lockfile = dependency_files.find { |f| f.name == "composer.lock" }
          raise "No composer.lock!" unless lockfile
          lockfile
        end

        def php_helper_path
          project_root = File.join(File.dirname(__FILE__), "../../../..")
          File.join(project_root, "helpers/php/bin/run.php")
        end

        def packagist_listing
          return @packagist_listing unless @packagist_listing.nil?

          response = Excon.get(
            "https://packagist.org/p/#{dependency.name}.json",
            idempotent: true,
            middlewares: SharedHelpers.excon_middleware
          )

          return nil unless response.status == 200

          @packagist_listing = JSON.parse(response.body)
        end
      end
    end
  end
end
