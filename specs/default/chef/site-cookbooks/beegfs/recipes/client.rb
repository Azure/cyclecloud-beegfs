include_recipe "::default"

packages = case node['platform_family']
           when 'rhel'
             %w{beegfs-client beegfs-helperd beegfs-utils gcc gcc-c++}.each do |pkg|
              package pkg do
                not_if "rpm -qa | grep #{pkg}"
              end
           end
           when 'debian'
             %w{beegfs-client beegfs-helperd beegfs-utils gcc cpp}.each { |p| package p }
end

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

# On some centos 7 images running RDMA networking we may need to rebuild the beegfs client to support
# the networking options - see https://community.mellanox.com/s/article/howto-configure-and-test-beegfs-with-rdma
bash "Update beegfs-client autobuild.conf" do
  code <<-'EOH'
sed -i 's/^buildArgs=.*/buildArgs=-j8 BEEGFS_OPENTK_IBVERBS=1 OFED_INCLUDE_PATH=\/usr\/src\/ofa_kernel\/default\/include\//' /etc/beegfs/beegfs-client-autobuild.conf
  EOH
  only_if { node['platform_family'] == 'rhel' }
  only_if { ::File.directory? "/usr/src/ofa_kernel/default/include/" }
end

execute "Rebuild beegfs-client" do
  command "/etc/init.d/beegfs-client rebuild"
  only_if { node['platform_family'] == 'rhel' }
  only_if { ::File.directory? "/usr/src/ofa_kernel/default/include/" }
end

execute "Mount BeeGFS" do
  command "echo '#{node["beegfs"]["mount_point"]} /etc/beegfs/beegfs-client.conf' > /etc/beegfs/beegfs-mounts.conf"
  not_if "grep -q '#{node["beegfs"]["mount_point"]}' /etc/beegfs/beegfs-mounts.conf"
  notifies :restart, 'service[beegfs-client]', :immediately
end

service "beegfs-client" do
  action [:enable, :start]
end

