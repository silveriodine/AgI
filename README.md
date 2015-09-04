# Silver Iodine 

Silver Iodine (AgI) is a tool for quickly creating sets of `no-cloud` data source ISO files for VM images configured with `cloud-init`. The tool generates instance names, and hostnames to uniquely identify each VM on your behalf.

## Prerequisites / Dependencies

* [genisoimage](https://en.wikipedia.org/wiki/Cdrkit) or [mkisofs](https://en.wikipedia.org/wiki/Cdrtools)
* [qemu-img](http://wiki.qemu.org/Main_Page)
* [cloud-init configuration files](https://cloudinit.readthedocs.org/en/latest/topics/examples.html)

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
Output via the --print option allows the instances to be handled by scripts after creation.
```
for instance in \
    $(./AgI.rb --print names -C /tmp \
	 --name Test --count 3 --disk ~/ubuntu-vivid-server-cloudimg-amd64-disk1.img );\
do qemu-system-x86_64 -cpu host -machine accel=kvm -name $instance\
    -drive file=/tmp/${instance}.qcow2,if=virtio,media=disk\
    -drive file=/tmp/${instance}.iso,if=virtio,media=cdrom -usbdevice tablet\
    -net bridge,name=vbr0,br=vbr0,helper=/usr/lib/qemu/qemu-bridge-helper\
    -net nic,model=virtio & 
done
```
