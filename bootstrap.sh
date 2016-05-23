
. overcloudrc
nova keypair-add overcloud --pub-key ~/.ssh/id_rsa.pub

neutron net-create cluster-test --shared --router:external=True --provider:network_type flat --provider:physical_network datacentre

export FLOATING_IP_NET="192.0.2"
neutron subnet-create --name ext-subnet --allocation-pool start=${FLOATING_IP_NET}.50,end=${FLOATING_IP_NET}.64 --disable-dhcp --gateway ${FLOATING_IP_NET}.1 cluster-test "${FLOATING_IP_NET}.0/24"


# Either build a new image

if [ -e rhn.pass -a -e rhn.user ]; then
    #   https://rwmj.wordpress.com/2015/10/03/tip-updating-rhel-7-1-cloud-images-using-virt-customize-and-subscription-manager/
    image_date=20160302
    image_version=7.2

    # https://access.redhat.com/solutions/641193
    # Short version, log in as cloud-user

    wget http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/${image_version}/${image_date}.0/images/rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2

    #
    # Update the image to include required packages (host must be
    # RHEL73+ or Fedora 22+):
    #
   virt-customize  -a rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2 \
      --sm-credentials '$(cat rhn.user):file:rhn.pass' \
      --sm-register --sm-attach auto \
      --update
      --install "pcs,pacemaker,corosync,fence-agents-all,resource-agents,ntp"
      --sm-unregister 

   openstack image create --container-format bare --disk-format qcow2 --public --file rhel-guest-image-7.2-20160302.0.x86_64.qcow2 ha-guest

else
    # Create a new one? No success using these images yet
    virt-builder centos-7.2 --format qcow2 --install "pcs,pacemaker,corosync,fence-agents-all,resource-agents,ntp"
    openstack image create --container-format bare --disk-format qcow2 --public --file centos-7.2.qcow2 ha-guest

fi
