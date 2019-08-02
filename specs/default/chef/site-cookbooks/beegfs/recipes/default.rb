# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
yum_repository 'beegfs' do
  description "BeeGFS #{node['beegfs']['repo']['version']} (rhel#{node['platform_version'].to_i})"
  baseurl node['beegfs']['repo']['yum']['baseurl']
  gpgkey node['beegfs']['repo']['yum']['gpgkey']
  only_if { node['platform_family'] == 'rhel' }
end

apt_repository 'beegfs' do
  uri node['beegfs']['repo']['apt']['uri']
  components node['beegfs']['repo']['apt']['components']
  arch node['beegfs']['repo']['apt']['arch']
  distribution node['beegfs']['repo']['apt']['distribution']
  key node['beegfs']['repo']['apt']['key']
  only_if { node['platform_family'] == 'debian' }
end

include_recipe '::_search_manager'

# install the beegfs-client and utils package in each node.
packages = case node['platform_family']
when 'rhel'
  %w{beegfs-utils beegfs-client}.each do |pkg|
   package pkg do
     not_if "rpm -qa | grep #{pkg}"
   end
  end
when 'debian'
  %w{beegfs-utils beegfs-client}.each { |p| package p }
end


manager_ipaddress = node['beegfs']['manager_ipaddress']
beegfs_client_conf_file = '/etc/beegfs/beegfs-client.conf'
hostname_line = "sysMgmtdHost = #{manager_ipaddress}"

# Run the reconfig again if the manager host changes:
ruby_block "Update #{beegfs_client_conf_file}" do
  block do
    file = Chef::Util::FileEdit.new(beegfs_client_conf_file)
    file.search_file_replace_line(/^sysMgmtdHost/, hostname_line)
    file.write_file
  end
  not_if "grep -q '#{hostname_line}' #{beegfs_client_conf_file}"
end
