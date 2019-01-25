# Using CycleCloud for setting up a BeeGFS Cluster on Azure

A CycleCloud Project for starting a BeeGFS cluster in Azure. 

## Performance, Capacity and Cost Planning

The BeeGFS cluster here is a collection of VMs with attached Azure Premium Managed
disks. Each storage node hosts both the BeeGFS-Metadata and -Storage daemons with
one RAID array for each.

HPC workloads can have widely varying I/0 requirements. To understand the considerations
of the configuration options an example is offered here.  Configuration of storage node:

* Storage VM 
  * 2 - Metadata Disks (Raid0)
  * 4 - Storage Disks (Raid0)

Azure P30 represents the best performance/cost disk and offers 1TB of storage.
Using the P30 as a primary storage device, then each storage node would have 4TB capacity.
A rule of thumb is to use 1/4 metadata storage to object storage so 2 x P20 metadata
disks resulting in 1TB of metadata storage is a reasonable initial design.

With 4 x P30 the VM has access to *1 GB/s* or *30 kIOPS* whichever is less, based
on the specification of the block devices. A virtual machine also has a throughput 
allowance.  Consider using Standard_D32s_v3 as a storage VM which offers *768 MB/s* or *51.2 kIOPS*.

* Storage VM Standard_D32s_v3 (*768 MB/s*, *51.2 kIOPS*)
  * Metadata: 2 x P20 (total: 1 TB, *300 MB/s*, *4.6 kIOPS* )
  * Storage: 4 x P30 (total: 4 TB, *1 GB/s*, *30 kIOPS*)

A cluster can be constructed by 1 or more of these compute nodes where with each compute node added the 
net resources available to a pool of clients will grow proportionally.  

## Cluster Life-Cycle

It is possible to delete data and disks managed by CycleCloud in the CycleCloud UI.
This can result in data loss.  Here are the actions available in the CycleCloud management.

* Create Cluster - creates storage VMs and disks
* Add Node - add additional node will increase size & resources of cluster
* Shutdown/Deallocate Node - will suspend node but preserve disks.
* Start Deallocated Node - restore data and resources of deallocated node.
* Shutdown/Delete Node - delete VM and disks, data on disks will be destroyed.
* Terminate Cluster - delete all VMs and disks, all data destroyed.

It is possible to create a BeeGFS cluster, populate the data then when the workload
is finished, deallocate the VMs so that the cluster can be restarted.
This is helpful in controlling costs, because charges for the VMs will be suspended while
deallocated.  Keep in mind that disks will still accrue charges while the VMs are 
deallocated.

![CC VM Deallocate](/images/deallocate.png "Preserve data by deallocating VMs")

## Monitoring

This cluster includes a recipe for I/O monitoring in _Grafana_. By adding a _monitor_
node to the cluster a VM will start and host a monitoring UI. This service can be
accessed by _HTTP_ on port 3000 of the monitor host (username: `admin`, default_pw: `admin`).

![BeeGFS Monitoring](/images/grafana.png "Monitor IOPs, Througput, Requests")

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
