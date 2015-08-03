# Silver Iodine 

Silver Iodine (AgI) is a tool for quickly creating sets of `no-cloud` data source ISO files for VM images configured with `cloud-init`. The tool generates instance names, and hostnames to uniquely identify each VM on your behalf.

## Prerequisites / Dependencies

* [genisoimage](https://en.wikipedia.org/wiki/Cdrkit) or [mkisofs](https://en.wikipedia.org/wiki/Cdrtools)
* [qemu-img](http://wiki.qemu.org/Main_Page)

## Usage


#### Example 

At it's most basic, Silver Iodine can create a single ISO
```
./AgI.rb --name InstanceName
```
Alternatively a complex environment can be spawned quickly. 
```
./AgI.rb --disk ubuntu-cloud.img --directory /tmp \
--name LoadBalancer --count 2 --userdata lb.ud \
--name Database --count 2 --userdata db.ud \
--name WebServer --count 4 --userdata web.ud
```
