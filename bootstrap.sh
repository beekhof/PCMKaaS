
. overcloudrc
nova keypair-add overcloud --pub-key ~/.ssh/id_rsa.pub

neutron net-create cluster-test --shared --router:external=True --provider:network_type flat --provider:physical_network datacentre

export FLOATING_IP_NET="192.0.2"
neutron subnet-create --name ext-subnet --allocation-pool start=${FLOATING_IP_NET}.50,end=${FLOATING_IP_NET}.64 --disable-dhcp --gateway ${FLOATING_IP_NET}.1 cluster-test "${FLOATING_IP_NET}.0/24"

# https://access.redhat.com/solutions/641193
# Short version, log in as cloud-user
# Also useful: https://rwmj.wordpress.com/2015/10/03/tip-updating-rhel-7-1-cloud-images-using-virt-customize-and-subscription-manager/
wget http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/7.2/20160302.0/images/rhel-guest-image-7.2-20160302.0.x86_64.qcow2
openstack image create --container-format bare --disk-format qcow2 --public --file rhel-guest-image-7.2-20160302.0.x86_64.qcow2 RHEL72

#wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
#openstack image create --container-format bare --disk-format qcow2 --public --file CentOS-7-x86_64-GenericCloud.qcow2 CentOS7

#wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
#openstack image create --container-format bare --disk-format qcow2 --public --file cirros-0.3.4-x86_64-disk.img CirrOS


