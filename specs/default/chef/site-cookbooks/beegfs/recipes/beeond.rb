beegfs_repo_file = "/etc/yum.repos.d/beegfs.repo"
beegfs_rpm_gpg_key = node['beegfs']['rpm_gpg_key']

remote_file "BeeGFS repo file" do
  path beegfs_repo_file
  source node['beegfs']['repo_file_url']
end

execute "Import rpm gpg key" do
  command "rpm --import #{beegfs_rpm_gpg_key}"
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

execute "Build BeeGFS module" do
  command "/etc/init.d/beegfs-client rebuild && modprobe beegfs"
  not_if "lsmod | grep -q beegfs"
end
