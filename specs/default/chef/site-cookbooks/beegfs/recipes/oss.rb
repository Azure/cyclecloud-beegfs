# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
include_recipe "::default"
include_recipe "::_tune_beegfs"

packages = case node['platform_family']
  when 'rhel'
    %w{beegfs-storage}.each do |pkg|
     package pkg do
       not_if "rpm -qa | grep #{pkg}"
     end
  end
  when 'debian'
    %w{beegfs-storage}.each { |p| package p }
end

storage_directory = "#{node["beegfs"]["root_dir"]}/storage"
directory "#{storage_directory}" do
    recursive true
end

# manager_ipaddress = ::BeeGFS::Helpers.search_for_manager(node['cyclecloud']['cluster']['id'])
manager_ipaddress = node["beegfs"]["manager_ipaddress"]

chef_state =  node['cyclecloud']['chefstate']
beegfs_storage_conf_file = "/etc/beegfs//beegfs-storage.conf"

hostname_line = "sysMgmtdHost = #{manager_ipaddress}"


ruby_block "Update #{beegfs_storage_conf_file}" do
    block do
      file = Chef::Util::FileEdit.new(beegfs_storage_conf_file)
      file.search_file_replace_line(/^storeStorageDirectory/, "storeStorageDirectory = #{storage_directory}")
      file.search_file_replace_line(/^sysMgmtdHost/, hostname_line)
      file.search_file_replace_line(/^connMaxInternodeNum/, "connMaxInternodeNum = 800")
      file.search_file_replace_line(/^tuneNumWorkers/, "tuneNumWorkers = 128")
      file.search_file_replace_line(/^tuneFileReadAheadSize/, "tuneFileReadAheadSize = 32m")
      file.search_file_replace_line(/^tuneFileReadAheadTriggerSize/, "tuneFileReadAheadTriggerSize = 2m")
      file.search_file_replace_line(/^tuneFileReadSize/, "tuneFileReadSize = 256k")
      file.search_file_replace_line(/^tuneFileWriteSize/, "tuneFileWriteSize = 256k")
      file.search_file_replace_line(/^tuneWorkerBufSize/, "tuneWorkerBufSize = 16m")
      file.write_file
    end
    not_if "grep -q '#{hostname_line}' #{beegfs_storage_conf_file}"
end

defer_block "Defer starting beegfs until end of the converge" do
    directory "#{storage_directory}" do
       recursive true
    end

    service "beegfs-storage" do
        action [:enable, :start]
    end
end


