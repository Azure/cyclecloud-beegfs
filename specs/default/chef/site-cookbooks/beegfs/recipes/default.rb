# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
beegfs_repo_file = "/etc/yum.repos.d/beegfs.repo"
beegfs_rpm_gpg_key = node['beegfs']['rpm_gpg_key']

remote_file "BeeGFS repo file" do
    path beegfs_repo_file
    source node['beegfs']['repo_file_url']
end

execute "Import rpm gpg key" do
    command "rpm --import #{beegfs_rpm_gpg_key}"
end

include_recipe "::_search_manager"


# install the beegfs-client and utils package in each node. 
%w{beegfs-utils beegfs-client}.each { |p| package p }

manager_ipaddress = node["beegfs"]["manager_ipaddress"]
chef_state =  node['cyclecloud']['chefstate']
beegfs_client_conf_file = "/etc/beegfs/beegfs-client.conf"
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
