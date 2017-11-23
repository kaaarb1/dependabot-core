# frozen_string_literal: true

require "dependabot/update_checkers/python/pip"

module Dependabot
  module UpdateCheckers
    module Python
      class Pip
        class RequirementsUpdater
          attr_reader :requirements, :latest_version, :latest_resolvable_version

          def initialize(requirements:, latest_version:,
                         latest_resolvable_version:)
            @requirements = requirements

            @latest_version = Gem::Version.new(latest_version) if latest_version

            return unless latest_resolvable_version
            @latest_resolvable_version =
              Gem::Version.new(latest_resolvable_version)
          end

          def updated_requirements
            requirements.map do |req|
              if req[:file] == "setup.py"
                updated_setup_requirement(req)
              else
                updated_requirement(req)
              end
            end
          end

          private

          def updated_setup_requirement(req)
            return req unless latest_resolvable_version
            return req unless req.fetch(:requirement)
            return req if new_version_satisfies?(req)

            req_strings = req[:requirement].split(",").map(&:strip)

            new_requirement =
              if req_strings.any? { |r| ruby_requirement(r).exact? }
                find_and_update_equality_match(req_strings)
              elsif req_strings.any? { |r| r.start_with?("~=", "==") }
                tw_req = req_strings.find { |r| r.start_with?("~=", "==") }
                convert_twidle_to_range(
                  ruby_requirement(tw_req),
                  latest_resolvable_version
                )
              else
                update_requirements_range(req_strings)
              end

            req.merge(requirement: new_requirement)
          end

          def updated_requirement(req)
            return req unless latest_resolvable_version
            return req unless req.fetch(:requirement)

            requirement_strings = req[:requirement].split(",").map(&:strip)

            new_requirement =
              if requirement_strings.any? { |r| r.start_with?("==") }
                find_and_update_equality_match(requirement_strings)
              elsif requirement_strings.any? { |r| r.start_with?("~=") }
                tw_req = requirement_strings.find { |r| r.start_with?("~=") }
                update_twiddle_version(tw_req, latest_resolvable_version.to_s)
              elsif new_version_satisfies?(req)
                req.fetch(:requirement)
              else
                update_requirements_range(requirement_strings)
              end

            req.merge(requirement: new_requirement)
          end

          def new_version_satisfies?(req)
            ruby_requirement(req.fetch(:requirement)).
              satisfied_by?(latest_resolvable_version)
          end

          def find_and_update_equality_match(requirement_strings)
            if requirement_strings.any? { |r| ruby_requirement(r).exact? }
              # True equality match
              "==#{latest_resolvable_version}"
            else
              # Prefix match
              requirement_strings.find { |r| r.start_with?("==") }.
                sub(PythonRequirementParser::VERSION) do |v|
                  at_same_precision(latest_resolvable_version.to_s, v)
                end
            end
          end

          def ruby_requirement(requirement_string)
            requirement_array =
              requirement_string.split(",").map do |req_string|
                req_string = req_string.gsub("~=", "~>").gsub(/===?/, "=")
                next req_string unless req_string.include?(".*")

                # Note: This isn't perfect. It replaces the "!= 1.0.x"
                # case with "!= 1.0.0". There's no way to model this correctly
                # in Ruby :'(
                req_string.
                  split(".").
                  first(req_string.split(".").index("*") + 1).
                  join(".").
                  tr("*", "0").
                  gsub(/^(?<!!)=/, "~>")
              end
            Gem::Requirement.new(requirement_array)
          end

          def at_same_precision(new_version, old_version)
            # return new_version unless old_version.include?("*")

            count = old_version.split(".").count
            precision = old_version.split(".").index("*") || count

            new_version.
              split(".").
              first(count).
              map.with_index { |s, i| i < precision ? s : "*" }.
              join(".")
          end

          def update_requirements_range(requirement_strings)
            ruby_requirements =
              requirement_strings.map { |r| ruby_requirement(r) }

            updated_requirement_strings = ruby_requirements.flat_map do |r|
              next r.to_s if r.satisfied_by?(latest_resolvable_version)

              case op = r.requirements.first.first
              when "<", "<="
                op + update_greatest_version(r.to_s, latest_resolvable_version)
              when "!="
                nil
              else
                raise "Unexpected op for unsatisfied requirement: #{op}"
              end
            end.compact

            updated_requirement_strings.
              sort_by { |r| Gem::Requirement.new(r).requirements.first.last }.
              map(&:to_s).join(",").delete(" ")
          end

          # Updates the version in a "~>" constraint to allow the given version
          def update_twiddle_version(req_string, version_to_be_permitted)
            old_version = req_string.gsub("~=", "")
            "~=#{at_same_precision(version_to_be_permitted, old_version)}"
          end

          def convert_twidle_to_range(requirement, version_to_be_permitted)
            version = requirement.requirements.first.last
            version = version.release if version.prerelease?

            index_to_update = version.segments.count - 2

            ub_segments = version_to_be_permitted.segments
            ub_segments << 0 while ub_segments.count <= index_to_update
            ub_segments = ub_segments[0..index_to_update]
            ub_segments[index_to_update] += 1

            lb_segments = version.segments
            lb_segments.pop while lb_segments.last.zero?

            # Ensure versions have the same length as each other (cosmetic)
            length = [lb_segments.count, ub_segments.count].max
            lb_segments.fill(0, lb_segments.count...length)
            ub_segments.fill(0, ub_segments.count...length)

            ">=#{lb_segments.join('.')},<#{ub_segments.join('.')}"
          end

          # Updates the version in a "<" or "<=" constraint to allow the given
          # version
          def update_greatest_version(req_string, version_to_be_permitted)
            if version_to_be_permitted.is_a?(String)
              version_to_be_permitted =
                Gem::Version.new(version_to_be_permitted)
            end
            version = Gem::Version.new(req_string.gsub(/<=?/, ""))
            version = version.release if version.prerelease?

            index_to_update =
              version.segments.map.with_index { |seg, i| seg.zero? ? 0 : i }.max

            new_segments = version.segments.map.with_index do |_, index|
              if index < index_to_update
                version_to_be_permitted.segments[index]
              elsif index == index_to_update
                version_to_be_permitted.segments[index] + 1
              else 0
              end
            end

            new_segments.join(".")
          end
        end
      end
    end
  end
end
