# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
require 'spec_helper'

describe 'lustre::client' do
  context "Basic Test" do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(:platform => 'centos', :version => '6.5') do |node|
          node.override[:lustre][:version] = "6.6.6"
          node.automatic[:kernel][:release] = "some.kernel.release"
          node.override[:thunderball][:storedir] = "/tmp"
      end.converge("lustre::client")
    end

    before do
      stub_command("modinfo lustre").and_return(false)
      stub_command("which mount.lustre").and_return(false)
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with("/tmp/cycle/lustre/lustre-client-modules-6.6.6-some.kernel.release.rpm").and_return true
      allow(::File).to receive(:exist?).with("/tmp/cycle/lustre/lustre-client-6.6.6-some.kernel.release.rpm").and_return true
    end

    it 'downloads client + modules' do
      expect(chef_run).to get_thunderball("Download Lustre client").with(:url => "/cycle/lustre/lustre-client-6.6.6-some.kernel.release.rpm")
      expect(chef_run).to get_thunderball("Download Lustre client modules").with(:url => "/cycle/lustre/lustre-client-modules-6.6.6-some.kernel.release.rpm")
    end

    it 'installs Lustre client + modules' do
      expect(chef_run).to install_package('Install Lustre client modules').with(:source => "/tmp/cycle/lustre/lustre-client-modules-6.6.6-some.kernel.release.rpm")
      expect(chef_run).to install_package('Install Lustre client').with(:source => "/tmp/cycle/lustre/lustre-client-6.6.6-some.kernel.release.rpm")
    end

    it 'loads kernel modules' do
      expect(chef_run).to run_execute('modprobe lustre')
    end
  end
end
