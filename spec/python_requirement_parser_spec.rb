# frozen_string_literal: true

require "spec_helper"
require "python_requirement_parser"

describe PythonRequirementParser do
  def parse(line)
    requirement =
      line.chomp.match(described_class::INSTALL_REQ_WITH_REQUIREMENT)
    return if requirement.nil?

    requirements =
      requirement[:requirements].to_s.
      to_enum(:scan, described_class::REQUIREMENT).
      map do
        {
          comparison: Regexp.last_match[:comparison],
          version: Regexp.last_match[:version]
        }
      end

    {
      name: requirement[:name],
      requirements: requirements
    }
  end

  describe ".parse" do
    subject { parse(line) }

    context "with a blank line" do
      let(:line) { "" }
      it { is_expected.to be_nil }
    end

    context "with just a line break" do
      let(:line) { "\n" }
      it { is_expected.to be_nil }
    end

    context "with a non-requirement line" do
      let(:line) { "# This is just a comment" }
      it { is_expected.to be_nil }
    end

    context "with no specification" do
      let(:line) { "luigi" }
      it { is_expected.to be_nil }

      context "with a comment" do
        let(:line) { "luigi==0.1.0 # some comment" }
        its([:name]) { is_expected.to eq "luigi" }
        its([:requirements]) do
          is_expected.to eq [{ comparison: "==", version: "0.1.0" }]
        end
      end
    end

    context "with a simple specification" do
      let(:line) { "luigi == 0.1.0" }
      its([:requirements]) do
        is_expected.to eq [{ comparison: "==", version: "0.1.0" }]
      end

      context "without spaces" do
        let(:line) { "luigi==0.1.0" }
        its([:name]) { is_expected.to eq "luigi" }
        its([:requirements]) do
          is_expected.to eq [{ comparison: "==", version: "0.1.0" }]
        end
      end
    end

    context "with multiple specifications" do
      let(:line) { "luigi == 0.1.0, <= 1" }
      its([:requirements]) do
        is_expected.to eq([
                            { comparison: "==", version: "0.1.0" },
                            { comparison: "<=", version: "1" }
                          ])
      end

      context "with a comment" do
        let(:line) { "luigi == 0.1.0, <= 1 # some comment" }
        its([:requirements]) do
          is_expected.to eq([
                              { comparison: "==", version: "0.1.0" },
                              { comparison: "<=", version: "1" }
                            ])
        end
      end
    end
  end
end
