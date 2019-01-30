include_recipe "::default"

packages = case node['platform_family']
           when 'rhel'
             %w{beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++}
           when 'debian'
             %w{beegfs-client beegfs-helperd beegfs-utils gcc cpp}
           end

packages.each { |p| package p }

# Problem with some images running an outdated kernel version,
# where the kernel headers don't exist in the repos anymore.
# Enable the Centos Vault repos

# Add the centos vault mirrors for the platform version we are on
%w(os updates).each do |id|
  yum_repository "centos-#{node[:platform_version]}-#{id}" do
    baseurl "http://vault.centos.org/#{node[:platform_version]}/#{id}/$basearch/"
    gpgkey "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-#{node[:platform_version].to_i}"
    action :create
    not_if "yum list kernel-devel-$(uname -r)"
    only_if { node['platform_family'] == 'rhel' }
  end
end

# Install the kernel-devel package for our platform
execute "Installing kernel-devel version that matches kernel" do
  command 'yum install -y "kernel-devel-uname-r == $(uname -r)"'
  not_if "rpm -qa | grep kernel-devel | grep $(uname -r)"
  only_if { node['platform_family'] == 'rhel' }
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

