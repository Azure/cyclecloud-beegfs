# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
manager_ipaddress = nil
cluster_id = node['cyclecloud']['cluster']['id']

# if this is the manager node, or if the client has specifed a ipaddress, use it
if node["recipes"].include? "beegfs::client" 
    if not node["beegfs"]["client"]["manager_ipaddress"].nil? 
        manager_ipaddress = node["beegfs"]["client"]["manager_ipaddress"]          
    elsif not node["beegfs"]["client"]["cluster_name"].nil?
        cluster_id = node["beegfs"]["client"]["cluster_name"]
    end
elsif node["recipes"].include? "beegfs::manager"
    manager_ipaddress = node["ipaddress"]
end

# Search for manager ipaddress otherwise:
if manager_ipaddress.nil?
    nodes = BeeGFS::Helpers.search_for_manager(1, 30) do
        nodes = cluster.search(:clusterUID => cluster_id).select { |n|
            if not n['beegfs'].nil?
                if not n['beegfs']['is_manager'].nil?
                    Chef::Log.info("Found #{n['ipaddress']} as BeeGFS manager")
                end
            end
        }
    end
    if nodes.length > 1
        raise("Found more than one manager node")
    end
    manager_ipaddress = nodes[0]['ipaddress'] 
end

node.override["beegfs"]["manager_ipaddress"] = manager_ipaddress
