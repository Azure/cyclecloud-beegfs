# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
include_recipe "::default"
include_recipe "::_tune_beegfs"

%w{beegfs-meta}.each { |p| package p }

meta_directory = "#{node["beegfs"]["root_dir"]}/meta"
directory "#{meta_directory}" do
    recursive true
end

# manager_ipaddress = ::BeeGFS::Helpers.search_for_manager(node['cyclecloud']['cluster']['id'])
manager_ipaddress = node["beegfs"]["manager_ipaddress"]

chef_state =  node['cyclecloud']['chefstate']
beegfs_meta_conf_file = "/etc/beegfs/beegfs-meta.conf"
hostname_line = "sysMgmtdHost = #{manager_ipaddress}"

service "beegfs-meta" do
    action [:enable]
end

# Run the reconfig again if the manager host changes:
ruby_block "Update #{beegfs_meta_conf_file}" do
    block do
      file = Chef::Util::FileEdit.new(beegfs_meta_conf_file)
      file.search_file_replace_line(/^storeMetaDirectory/, "storeMetaDirectory = #{meta_directory}")
      file.search_file_replace_line(/^sysMgmtdHost/, hostname_line)
      file.search_file_replace_line(/^connMaxInternodeNum/, "connMaxInternodeNum = 800")
      file.search_file_replace_line(/^tuneNumWorkers/, "tuneNumWorkers = 128")
      file.write_file
    end
    not_if "grep -q '#{hostname_line}' #{beegfs_meta_conf_file}"
    notifies :restart, 'service[beegfs-meta]', :immediately 
end

