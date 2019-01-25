default['beegfs']['repo']['version'] = 'latest-stable'
default['beegfs']['repo']['key_version'] = 'beegfs_7_1'
default['beegfs']['repo']['yum']['baseurl'] = "https://www.beegfs.io/release/#{node['beegfs']['repo']['version']}/dists/rhel#{node['platform_version'].to_i}"
default['beegfs']['repo']['yum']['gpgkey'] = "https://www.beegfs.io/release/#{node['beegfs']['repo']['key_version']}/gpg/RPM-GPG-KEY-beegfs"

default['beegfs']['repo']['apt']['uri'] = "https://www.beegfs.io/release/#{node['beegfs']['repo']['version']}"
default['beegfs']['repo']['apt']['arch'] = 'amd64'

# Dependencies only in-place for Ubuntu 18.04
# Repo uses Debian codenames and only offers jessie, and stretch targets
default['beegfs']['repo']['apt']['distribution'] = (node['lsb'].key?('codename') && node['lsb']['codename'] == 'jessie') ? 'jessie' : 'stretch'
default['beegfs']['repo']['apt']['components'] = ['non-free']
default['beegfs']['repo']['apt']['key'] = "https://www.beegfs.io/release/#{node['beegfs']['repo']['version']}/gpg/DEB-GPG-KEY-beegfs"

# the directory on the MGS, MDS and OSS where the BeeGFS data resides
default['beegfs']['root_dir'] = '/data/beegfs'

default['beegfs']['manager_ipaddress'] = nil

# BeeeGFS Clients
# Allow clients to specify a specific MGS, or a clustername to connect to
# Order of precedence:
# 1. manager_ipaddress
# 2. cluster_name
# 3. the parent cluster the client belongs to
default['beegfs']['client']['manager_ipaddress'] = nil
default['beegfs']['client']['cluster_name'] = nil

# The mount point for the BeeGFS clients
default['beegfs']['client']['mount_point'] = '/mnt/beegfs'
