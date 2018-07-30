default["beegfs"]["repo_file_url"] = "https://www.beegfs.io/release/beegfs_7/dists/beegfs-rhel7.repo"
default["beegfs"]["rpm_gpg_key"] = "https://www.beegfs.io/release/beegfs_7/gpg/RPM-GPG-KEY-beegfs"

# the directory on the MGS, MDS and OSS where the BeeGFS data resides
default["beegfs"]["root_dir"] = "/data/beegfs"

default["beegfs"]["manager_ipaddress"] = nil


# BeeeGFS Clients
# Allow clients to specify a specific MGS, or a clustername to connect to
# Order of precedence:
# 1. manager_ipaddress
# 2. cluster_name
# 3. the parent cluster the client belongs to
default["beegfs"]["client"]["manager_ipaddress"] = nil
default["beegfs"]["client"]["cluster_name"] = nil

# The mount point for the BeeGFS clients
default["beegfs"]["client"]["mount_point"] = "/mnt/beegfs"