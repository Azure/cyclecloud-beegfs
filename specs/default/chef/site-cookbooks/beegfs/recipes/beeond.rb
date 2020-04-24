yum_repository 'beegfs' do
  description "BeeGFS #{node['beegfs']['repo']['version']} (rhel#{node['platform_version'].to_i})"
  baseurl node['beegfs']['repo']['yum']['baseurl']
  gpgkey node['beegfs']['repo']['yum']['gpgkey']
  only_if { node['platform_family'] == 'rhel' }
end

%w{beegfs-client beegfs-helperd beegfs-utils beeond gcc gcc-c++}.each { |p| package p }

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
  end
end 

# Install the kernel-devel package for our platform
execute "Installing kernel-devel version that matches kernel" do
  command 'yum install -y "kernel-devel-uname-r == $(uname -r)"'
  not_if "rpm -qa | grep kernel-devel | grep $(uname -r)"
end

service "beegfs-helperd" do
  action [:enable, :start]
end

directory "/var/log/beeond_logs" do
  action :create
  mode 0777
end

directory "/mnt/resource/beeond_logs" do
  action :create
  mode 0777
end

directory "/mnt/resource/beeond" do
  action :create
  mode 0777
end

directory "/mnt/beeond" do
  action :create
  mode 0777
end

cookbook_file "/opt/beegfs/sbin/beeond" do
  action :create
  source "beeond"
  mode 0755
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

execute "Build BeeGFS module" do
  command "/etc/init.d/beegfs-client rebuild && modprobe beegfs"
  not_if "lsmod | grep -q beegfs"
end
