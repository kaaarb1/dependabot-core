# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_file"
require "dependabot/file_parsers/python/pip"
require_relative "../shared_examples_for_file_parsers"

RSpec.describe Dependabot::FileParsers::Python::Pip do
  it_behaves_like "a dependency file parser"

  let(:files) { [requirements] }
  let(:requirements) do
    Dependabot::DependencyFile.new(
      name: "requirements.txt",
      content: requirements_body
    )
  end
  let(:requirements_body) do
    fixture("python", "requirements", "version_specified.txt")
  end
  let(:parser) { described_class.new(dependency_files: files, repo: "org/nm") }

  describe "parse" do
    subject(:dependencies) { parser.parse }

    its(:length) { is_expected.to eq(2) }

    context "with a version specified" do
      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("psycopg2")
          expect(dependency.version).to eq("2.6.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.6.1",
                file: "requirements.txt",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end
    end

    context "with comments" do
      let(:requirements_body) do
        fixture("python", "requirements", "comments.txt")
      end
      its(:length) { is_expected.to eq(2) }

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("psycopg2")
          expect(dependency.version).to eq("2.6.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.6.1",
                file: "requirements.txt",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end
    end

    context "with extras" do
      let(:requirements_body) do
        fixture("python", "requirements", "extras.txt")
      end

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("psycopg2")
          expect(dependency.version).to eq("2.6.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.6.1",
                file: "requirements.txt",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end
    end

    context "with an 'unsafe' name" do
      let(:requirements_body) do
        "mypy_extensions==0.2.0"
      end

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right name" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("mypy_extensions")
        end
      end
    end

    context "with invalid lines" do
      let(:requirements_body) do
        fixture("python", "requirements", "invalid_lines.txt")
      end

      it "raises a Dependabot::DependencyFileNotEvaluatable error" do
        expect { parser.parse }.
          to raise_error(Dependabot::DependencyFileNotEvaluatable)
      end
    end

    context "with no version specified" do
      let(:requirements_body) do
        fixture("python", "requirements", "version_not_specified.txt")
      end

      its(:length) { is_expected.to eq(2) }
    end

    context "with prefix matching specified" do
      let(:requirements_body) do
        fixture("python", "requirements", "prefix_match.txt")
      end

      its(:length) { is_expected.to eq(2) }

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("psycopg2")
          expect(dependency.version).to be_nil
          expect(dependency.requirements.first[:requirement]).to eq("==2.6.*")
        end
      end
    end

    context "with a version specified as between two constraints" do
      let(:requirements_body) do
        fixture("python", "requirements", "version_between_bounds.txt")
      end

      its(:length) { is_expected.to eq(2) }

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("psycopg2")
          expect(dependency.version).to be_nil
          expect(dependency.requirements.first[:requirement]).
            to eq("<=3.0.0,==2.6.1")
        end
      end
    end

    context "with a git dependency" do
      let(:requirements_body) do
        fixture("python", "requirements", "with_git_dependency.txt")
      end

      its(:length) { is_expected.to eq(1) }
    end

    context "with a constraints file" do
      let(:files) { [requirements, constraints] }
      let(:requirements_body) do
        fixture("python", "requirements", "with_constraints.txt")
      end

      context "that aren't specific" do
        let(:constraints) do
          Dependabot::DependencyFile.new(
            name: "constraints.txt",
            content: fixture("python", "constraints", "less_than.txt")
          )
        end

        its(:length) { is_expected.to eq(1) }

        describe "the first dependency" do
          subject(:dependency) { dependencies.first }

          it "has the right details" do
            expect(dependency).to be_a(Dependabot::Dependency)
            expect(dependency.name).to eq("requests")
            expect(dependency.version).to be_nil
            expect(dependency.requirements.first[:requirement]).to be_nil
            expect(dependency.requirements.last[:requirement]).
              to eq("<2.0.0")
          end
        end
      end

      context "that are specific" do
        let(:constraints) do
          Dependabot::DependencyFile.new(
            name: "constraints.txt",
            content: fixture("python", "constraints", "specific.txt")
          )
        end

        its(:length) { is_expected.to eq(1) }

        describe "the first dependency" do
          subject(:dependency) { dependencies.first }

          it "has the right details" do
            expect(dependency).to be_a(Dependabot::Dependency)
            expect(dependency.name).to eq("requests")
            expect(dependency.version).to eq("2.0.0")
            expect(dependency.requirements).to match_array(
              [
                {
                  requirement: nil,
                  file: "requirements.txt",
                  groups: [],
                  source: nil
                },
                {
                  requirement: "==2.0.0",
                  file: "constraints.txt",
                  groups: [],
                  source: nil
                }
              ]
            )
          end
        end

        context "when the requirements file is specific, too" do
          let(:requirements_body) do
            fixture("python", "requirements", "specific_with_constraints.txt")
          end

          its(:length) { is_expected.to eq(1) }

          describe "the first dependency" do
            subject(:dependency) { dependencies.first }

            it "has the right details" do
              expect(dependency).to be_a(Dependabot::Dependency)
              expect(dependency.name).to eq("requests")
              expect(dependency.version).to eq("2.0.0")
              expect(dependency.requirements).to match_array(
                [
                  {
                    requirement: "==2.0.0",
                    file: "constraints.txt",
                    groups: [],
                    source: nil
                  },
                  {
                    requirement: "==2.4.1",
                    file: "requirements.txt",
                    groups: [],
                    source: nil
                  }
                ]
              )
            end
          end
        end
      end
    end

    context "with reference to its setup.py" do
      let(:files) { [requirements, setup_file] }
      let(:requirements) do
        Dependabot::DependencyFile.new(
          name: "requirements.txt",
          content: fixture("python", "requirements", "with_setup_path.txt")
        )
      end
      let(:setup_file) do
        Dependabot::DependencyFile.new(
          name: "setup.py",
          content: fixture("python", "setup_files", "setup.py")
        )
      end

      # setup.py dependencies get imported
      its(:length) { is_expected.to eq(15) }

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("requests")
          expect(dependency.version).to eq("2.1.0")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.1.0",
                file: "requirements.txt",
                groups: [],
                source: nil
              },
              {
                requirement: "==2.12.*",
                file: "setup.py",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end
    end

    context "with child requirement files" do
      let(:files) { [requirements, child_requirements] }
      let(:requirements_body) do
        fixture("python", "requirements", "cascading.txt")
      end
      let(:child_requirements) do
        Dependabot::DependencyFile.new(
          name: "more_requirements.txt",
          content: fixture("python", "requirements", "version_specified.txt")
        )
      end

      its(:length) { is_expected.to eq(3) }

      describe "the first dependency" do
        subject(:dependency) { dependencies.first }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("requests")
          expect(dependency.version).to eq("2.4.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.4.1",
                file: "requirements.txt",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end

      describe "the last dependency" do
        subject(:dependency) { dependencies.last }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("luigi")
          expect(dependency.version).to eq("2.2.0")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==2.2.0",
                file: "more_requirements.txt",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end
    end

    context "with a setup.py" do
      let(:files) { [setup_file] }
      let(:setup_file) do
        Dependabot::DependencyFile.new(
          name: "setup.py",
          content: fixture("python", "setup_files", "setup.py")
        )
      end

      its(:length) { is_expected.to eq(15) }

      describe "an install_requires dependencies" do
        subject(:dependency) { dependencies.find { |d| d.name == "boto3" } }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("boto3")
          expect(dependency.version).to eq("1.3.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==1.3.1",
                file: "setup.py",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end

      describe "a setup_requires dependencies" do
        subject(:dependency) { dependencies.find { |d| d.name == "numpy" } }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("numpy")
          expect(dependency.version).to eq("1.11.0")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==1.11.0",
                file: "setup.py",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end

      describe "a tests_require dependencies" do
        subject(:dependency) { dependencies.find { |d| d.name == "responses" } }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("responses")
          expect(dependency.version).to eq("0.5.1")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==0.5.1",
                file: "setup.py",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end

      describe "an extras_require dependencies" do
        subject(:dependency) { dependencies.find { |d| d.name == "flask" } }

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("flask")
          expect(dependency.version).to eq("0.12.2")
          expect(dependency.requirements).to eq(
            [
              {
                requirement: "==0.12.2",
                file: "setup.py",
                groups: [],
                source: nil
              }
            ]
          )
        end
      end

      context "without a `tests_require` key" do
        let(:setup_file) do
          Dependabot::DependencyFile.new(
            name: "setup.py",
            content: fixture("python", "setup_files", "no_tests_require.py")
          )
        end

        its(:length) { is_expected.to eq(12) }
      end

      context "with a `print` statement" do
        let(:setup_file) do
          Dependabot::DependencyFile.new(
            name: "setup.py",
            content: fixture("python", "setup_files", "with_print.py")
          )
        end

        its(:length) { is_expected.to eq(14) }
      end

      context "with an `open` statement" do
        let(:setup_file) do
          Dependabot::DependencyFile.new(
            name: "setup.py",
            content: fixture("python", "setup_files", "with_open.py")
          )
        end

        its(:length) { is_expected.to eq(14) }
      end

      context "with the setup.py from requests" do
        let(:setup_file) do
          Dependabot::DependencyFile.new(
            name: "setup.py",
            content: fixture("python", "setup_files", "requests_setup.py")
          )
        end

        its(:length) { is_expected.to eq(13) }
      end

      context "with an import of a config file" do
        let(:setup_file) do
          Dependabot::DependencyFile.new(
            name: "setup.py",
            content: fixture("python", "setup_files", "imports_version.py")
          )
        end

        its(:length) { is_expected.to eq(14) }
      end
    end
  end
end
