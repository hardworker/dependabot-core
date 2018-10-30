# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/update_checkers/cocoa/cocoapods"
require_relative "../shared_examples_for_update_checkers"

RSpec.describe Dependabot::UpdateCheckers::Cocoa::CocoaPods do
  it_behaves_like "an update checker"

  before do
    master_url = "https://api.github.com/repos/CocoaPods/Specs/commits/master"
    stub_request(:get, master_url).to_return(status: 304)
  end

  let(:checker) do
    described_class.new(
      dependency: dependency,
      dependency_files: dependency_files,
      github_access_token: "token"
    )
  end

  let(:dependency_files) { [podfile, podfile_lock] }

  let(:dependency) do
    Dependabot::Dependency.new(
      name: "Alamofire",
      version: "3.0.0",
      requirements: requirements,
      package_manager: "cocoapods"
    )
  end

  let(:requirements) do
    [{
      requirement: "~> 3.0.0",
      file: "Podfile",
      groups: []
    }]
  end

  let(:podfile) do
    Dependabot::DependencyFile.new(content: podfile_content, name: "Podfile")
  end
  let(:podfile_lock) do
    Dependabot::DependencyFile.new(
      content: lockfile_content,
      name: "Podfile.lock"
    )
  end
  let(:podfile_content) { fixture("cocoa", "podfiles", "version_specified") }
  let(:lockfile_content) { fixture("cocoa", "lockfiles", "version_specified") }

  describe "#latest_version" do
    subject(:latest_version) { checker.latest_version }

    it "delegates to latest_resolvable_version" do
      expect(checker).to receive(:latest_resolvable_version)
      latest_version
    end
  end

  describe "#latest_resolvable_version" do
    subject { checker.latest_resolvable_version }

    context "for a dependency from the master source" do
      # Stubbing the CocoaPods spec repo is hard. Instead just spec that the
      # latest version is high
      it { is_expected.to be >= Gem::Version.new("4.4.0") }

      context "with a version conflict at the latest version" do
        let(:podfile_content) do
          fixture("cocoa", "podfiles", "version_conflict")
        end
        let(:lockfile_content) do
          fixture("cocoa", "lockfiles", "version_conflict")
        end

        it { is_expected.to eq(Gem::Version.new("3.5.1")) }
      end
    end

    context "for a dependency with a git source" do
      let(:podfile_content) { fixture("cocoa", "podfiles", "git_source") }
      let(:lockfile_content) { fixture("cocoa", "lockfiles", "git_source") }

      it { is_expected.to be_nil }
    end

    context "for a dependency file with a specified source repo" do
      before do
        specs_url =
          "https://api.github.com/repos/dependabot/Specs/commits/master"
        stub_request(:get, specs_url).to_return(status: 304)
      end

      let(:podfile_content) { fixture("cocoa", "podfiles", "private_source") }
      let(:lockfile_content) { fixture("cocoa", "lockfiles", "private_source") }

      it { is_expected.to eq(Gem::Version.new("4.3.0")) }
    end

    context "for a dependency with a specified source repo (inline)" do
      before do
        specs_url =
          "https://api.github.com/repos/dependabot/Specs/commits/master"
        stub_request(:get, specs_url).to_return(status: 304)
      end

      let(:podfile_content) { fixture("cocoa", "podfiles", "inline_source") }
      let(:lockfile_content) { fixture("cocoa", "lockfiles", "inline_source") }

      it { is_expected.to eq(Gem::Version.new("4.3.0")) }
    end
  end

  describe "#updated_requirements" do
    subject(:updated_requirements) { checker.updated_requirements }

    context "with a Podfile and a Podfile.lock" do
      it "delegates to CocoaPods::RequirementsUpdater with the right params" do
        expect(
          Dependabot::UpdateCheckers::Cocoa::CocoaPods::RequirementsUpdater
        ).to receive(:new).with(
          requirements: requirements,
          existing_version: "3.0.0",
          latest_version: instance_of(String),
          latest_resolvable_version: instance_of(String)
        ).and_call_original

        expect(updated_requirements.count).to eq(1)
        expect(updated_requirements.first[:requirement]).to start_with("~>")
      end
    end

    context "with only a Podfile" do
      let(:dependency_files) { [podfile] }
      it "raises" do
        # TODO: Extend functionality to match Ruby
        expect { updated_requirements }.to raise_error(/No Podfile.lock!/)
      end
    end
  end
end