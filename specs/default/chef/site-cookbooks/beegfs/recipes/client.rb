# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
include_recipe "::default"
%w{beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++}.each { |p| package p }

# Problem with some images running an outdated kernel version,
# where the kernel headers don't exist in the repos anymore.
# mitigate some failures by checking if kernel-devel has already been installed
execute "Installing kernel devel version that matches kernel" do
  command 'yum install -y "kernel-devel-uname-r == $(uname -r)"'
  not_if "rpm -qa | grep kernel-devel | grep $(uname -r)"
end

service "beegfs-helperd" do
  action [:enable, :start]
end

execute "Mount BeeGFS" do
  command "echo '#{node["beegfs"]["mount_point"]} /etc/beegfs/beegfs-client.conf' > /etc/beegfs/beegfs-mounts.conf"
  not_if "grep -q '#{node["beegfs"]["mount_point"]}' /etc/beegfs/beegfs-mounts.conf"
  notifies :restart, 'service[beegfs-client]', :immediately  
end

service "beegfs-client" do
  action [:enable, :start]
end

