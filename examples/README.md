# Mounting BeeGFS in a Cluster

## Pre-requisites 
- A running BeeGFS cluster started through CycleCloud
- CentOS VMs (_This implemenation of the BeeGFS client is only supported on CentOS currently_)

## How to add a BeeGFS mount to a cluster template
The file in this directory `pbs_beegfs_template.txt` serves as an example that illustrates how one could discover and mount an existing BeeGFS onto a new cluster. 

- Lines 21 and 22 specifies that the BeeGFS project specification should be added to all node of the cluster 
```
        [[[cluster-init cyclecloud/beegfs:default:1.0.0]]]
        [[[cluster-init cyclecloud/beegfs:client:1.0.0]]]
```
- Lines 25 and 26 adds two config attributes to each cluster node. `beegfs.client.cluster_name` tells the node the name of the BeeGFS cluster to mount, and `beegfs.client.mount_point` specifies where that mount point is on the nodes.
```
        beegfs.client.cluster_name = $BeeGFSClusterName
        beegfs.client.mount_point = $BeeGFSMountPt
``` 
- The above two attributes are parameterized, and lines 98-114 defines these parameters. These parameters will also appear in the cluster creation UI.

## Using this template

- Import the template:
    $ cyclecloud import_template PBS-BeeGFS -f pbs_beegfs_template.txt 

- From the CycleCloud UI, create a new cluster. You should find PBS-BeeGFS as an available cluster type. 
    - The Required Settings of the cluster creation form provides a dropdown to select the name of the BeeGFS cluster. You should be able to find the name of the BeeGFS cluster in here if it is running through the same CycleCloud server.



## Using Beeond

- Import the template: 
    $ cyclecloud import_template PBS-Beeond -f pbs_beeond_template.txt -c PBS-BeeGFS

- To mount a Beeond filesystem as part of your job script, run:
    $ beeond start -n $PBS_NODEFILE -d /mnt/resource/beeond -c /mnt/beeond

- To stop the Beeond filesystem at the end of your job script, run:
    $ beeond stop -n $PBS_NODEFILE
