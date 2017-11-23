# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/file_updaters/ruby/bundler/requirement_replacer"

RSpec.describe Dependabot::FileUpdaters::Ruby::Bundler::RequirementReplacer do
  let(:replacer) do
    described_class.new(
      dependency: dependency,
      file_type: file_type,
      updated_requirement: updated_requirement
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: "1.5.0",
      previous_version: "1.2.0",
      requirements: requirement,
      package_manager: "bundler"
    )
  end
  let(:requirement) do
    [
      {
        source: nil,
        file: "Gemfile",
        requirement: updated_requirement,
        groups: []
      }
    ]
  end
  let(:updated_requirement) { "~> 1.5.0" }

  let(:dependency_name) { "business" }
  let(:file_type) { :gemfile }

  describe "#rewrite" do
    subject(:rewrite) { replacer.rewrite(content) }

    let(:content) { fixture("ruby", "gemfiles", "git_source") }

    context "with a Gemfile" do
      let(:file_type) { :gemfile }

      context "when the declaration spans multiple lines" do
        let(:content) { fixture("ruby", "gemfiles", "git_source") }
        it { is_expected.to include(%(gem "business", "~> 1.5.0",\n    git: )) }
        it { is_expected.to include(%(gem "statesman", "~> 1.2.0")) }
      end

      context "within a source block" do
        let(:content) do
          "source 'https://example.com' do\n"\
          "  gem \"business\", \"~> 1.0\", require: true\n"\
          "end"
        end
        it { is_expected.to include(%(gem "business", "~> 1.5.0", require:)) }
      end

      context "with multiple requirements" do
        let(:content) { %(gem "business", "~> 1.0", ">= 1.0.1") }
        it { is_expected.to eq(%(gem "business", "~> 1.5.0")) }

        context "given as an array" do
          let(:content) { %(gem "business", [">= 1", "<3"], require: true) }
          it { is_expected.to eq(%(gem "business", "~> 1.5.0", require: true)) }
        end

        context "for the new requirement" do
          let(:updated_requirement) { ">= 1.0, < 3.0" }
          it { is_expected.to eq(%(gem "business", ">= 1.0", "< 3.0")) }
        end
      end

      context "with a dependency that uses single quotes" do
        let(:content) { %(gem "business", '~> 1.0') }
        it { is_expected.to eq(%(gem "business", '~> 1.5.0')) }
      end

      context "with a dependency that uses quote brackets" do
        let(:content) { %(gem "business", %(1.0)) }
        it { is_expected.to eq(%(gem "business", %(~> 1.5.0))) }
      end

      context "with a dependency that uses doesn't have a space" do
        let(:content) { %(gem "business", "~>1.0") }
        it { is_expected.to eq(%(gem "business", "~>1.5.0")) }
      end
    end

    context "with a gemspec" do
      let(:file_type) { :gemspec }

      let(:content) { fixture("ruby", "gemspecs", "example") }

      context "when declared with `add_runtime_dependency`" do
        let(:dependency_name) { "bundler" }
        it { is_expected.to include(%(time_dependency "bundler", "~> 1.5.0")) }
      end

      context "when declared with `add_dependency`" do
        let(:dependency_name) { "excon" }
        it { is_expected.to include(%(add_dependency "excon", "~> 1.5.0")) }
      end

      context "when declared without a version" do
        let(:dependency_name) { "rake" }
        it { is_expected.to include(%(ent_dependency "rake"\n)) }
      end

      context "when declared with `add_development_dependency`" do
        let(:dependency_name) { "rspec" }
        it { is_expected.to include(%(ent_dependency "rspec", "~> 1.5.0"\n)) }
      end
    end
  end
end
