# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
include_recipe "::default"

# Make the Manager node searchable by the beegfs.is_manager tag
node.override["beegfs"]["is_manager"] = true
cluster.store_discoverable()

packages = case node['platform_family']
  when 'rhel'
    %w{beegfs-mgmtd beegfs-helperd beegfs-admon}.each do |pkg|
     package pkg do
       not_if "rpm -qa | grep #{pkg}"
     end
  end
  when 'debian'
    %w{beegfs-mgmtd beegfs-helperd beegfs-admon}.each { |p| package p }
end


mgmtd_directory = "#{node["beegfs"]["root_dir"]}/mgmtd"
directory "#{mgmtd_directory}" do
    recursive true
end

beegfs_mgmtd_conf_file = "/etc/beegfs/beegfs-mgmtd.conf"

service "beegfs-mgmtd" do
    action [:enable]
end

service "beegfs-admon" do
    action [:enable]
end

ruby_block "Update #{beegfs_mgmtd_conf_file}" do
    block do
      file = Chef::Util::FileEdit.new(beegfs_mgmtd_conf_file)  
      file.search_file_replace_line(/^storeMgmtdDirectory/, "storeMgmtdDirectory = #{mgmtd_directory}")
      file.write_file
    end  
    not_if "grep -q 'storeMgmtdDirectory = #{mgmtd_directory}' #{beegfs_mgmtd_conf_file} "
    notifies :restart, 'service[beegfs-mgmtd]', :immediately
end     

beegfs_admon_conf_file = "/etc/beegfs/beegfs-admon.conf"
hostname_line = "sysMgmtdHost = #{node[:hostname]}"
ruby_block "Update #{beegfs_admon_conf_file}" do
    block do
      file = Chef::Util::FileEdit.new(beegfs_admon_conf_file)  
      file.search_file_replace_line(/^sysMgmtdHost/, hostname_line)
      file.write_file
    end  
    not_if "grep -q '#{hostname_line}' #{beegfs_admon_conf_file}"
    notifies :restart, 'service[beegfs-admon]', :immediately
end     

# gotta add a cron for discovering master
