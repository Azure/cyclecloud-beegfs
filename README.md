# Using CycleCloud for setting up a BeeGFS Cluster on Azure

A CycleCloud Project for starting a BeeGFS cluster in Azure. 

## Performance, Capacity and Cost

This project includes two scenarios; one configuration based on low-latency local NVMe SSDs and one based on Azure Premium Disks.

| Scenario | Local Disk | Persistent Disk |
|---|---|---|
| VM Size | Standard_L8s_v2 | Standard_D16s_v3 |
| Disk | Local NVMe SSD  | Premium Disk (2 x P30) |
| Capacity | 1.9 TB | 2.0 TB  | 
| Node Throughput | 400 MB/s | 384 MB/s  |
| Node IOPS | 40000 | 10000  |
| Node $/month | $455  | $830  |
| Node Data Durability | 3 9's | 11 9's | 

These configurations have been designed and tested to have maximal performance-cost. 
The Local Disk scenario will show better performance, particularly latency and IOPS, 
but durability of data will be relatively lower. The performance (and capacity) of a 
cluster can be estimated as the 
performance of a single node multiplied by the number of storage nodes
in the cluster. This has been tested up to 32 nodes.

If cost-per-storage is more important that cost-per-performance then you can increase the size 
or quantity of additional premium disks attached. 
Increasing the attached disks will increase the capacity, but not the performance.

Using the persistent disks, the data on the cluster will be recoverable 
even in the event of unplanned node termination or VM scheduled maintenance. This is not so when using local disks as the disk is only 
stored locally and will be lost when the VM is deallocated.


## Cluster Life-Cycle for Local Disk (default)

For storage cluster based on local SSDs storage is not preserved across VM 
deallocations and restarts.

* Create Cluster - creates storage VMs and disks
* Add Node - add additional node will increase size & resources of cluster
* Shutdown/Delete Node - delete VM and disks, data on disks will be destroyed.
* Terminate Cluster - delete all VMs and disks, all data destroyed.


## Cluster Life-Cycle for Premium Disk

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
