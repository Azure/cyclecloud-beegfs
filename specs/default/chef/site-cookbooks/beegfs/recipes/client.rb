include_recipe "::default"
%w{beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++}.each { |p| package p }

# Problem with some images running an outdated kernel version,
# where the kernel headers don't exist in the repos anymore.
# mitigate some failures by checking if kernel-devel has already been installed

# Try specifing the kernel version and doing a yum install.
# ignore failues in this first try
execute "Installing kernel-devel version that matches kernel" do
  command 'yum install -y "kernel-devel-uname-r == $(uname -r)"'
  not_if "rpm -qa | grep kernel-devel | grep $(uname -r)"
  ignore_failure true
end

# If the above fails, update the centos-release, enable all repos
# and try installing kernel-devel again
execute "Enabling Centos vault repos and installing kernel-devel version that matches kernel" do
  command 'yum install -y centos-release; yum install -y --enablerepo=C*-base --enablerepo=C*-updates kernel-devel-$(uname -r)'
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

