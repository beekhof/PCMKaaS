image_version=7.2
image_date=20160302
image_target=rhel-ha-guest-${image_version}.qcow2
base="$PWD/$(dirname $0)"

. ~/overcloudrc
if [ 0 = 1 ]; then
    nova keypair-add overcloud --pub-key ~/.ssh/id_rsa.pub

    neutron net-create cluster-test --shared --router:external=True --provider:network_type flat --provider:physical_network datacentre

    export FLOATING_IP_NET="192.0.2"
    neutron subnet-create --name ext-subnet --allocation-pool start=${FLOATING_IP_NET}.50,end=${FLOATING_IP_NET}.64 --disable-dhcp --gateway ${FLOATING_IP_NET}.1 cluster-test "${FLOATING_IP_NET}.0/24"

    cat<<EOF>>~/.bashrc
export STACK="test"
export STACK_OPTS="cluster_size=2"
alias sl='heat stack-list'
alias sd='heat stack-delete \$STACK'
alias ss='heat resource-list -n5 --with-detail \$STACK'
alias sc='heat stack-create \$STACK -f "$base/cluster.yaml" -P "\$STACK_OPTS"'
alias nl='nova list'
alias rs='heat resource-show'
alias cl='nova console-log'
EOF

    cat<<EOF>>~/.ssh/config
Host $FLOATING_IP_NET.*
  User cloud-user
  StrictHostkeyChecking no
  UserKnownHostsFile /dev/null
EOF
fi

. ~/.bashrc

if [ ! -e rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2 ]; then
    wget http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/${image_version}/${image_date}.0/images/rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2
fi

if [ 1 = 1 ]; then
    # It should be possible to take the offical RH image,
    # define rh_subscription above and start using the
    # 'packages' directive.  However this does not work
    # due to SSL and Cert issues.
    #
    # By default one gets:
    #  https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/os/repodata/repomd.xml: [Errno 14] curl#77 - "Problem with the SSL CA cert (path? access rights?)"
    #
    # Adding:
    #  sed -i 's/insecure.*/insecure = 1/' /etc/rhsm/rhsm.conf
    #  sed -i 's/sslverify.*/sslverify = 0/' /etc/yum.repos.d/redhat.repo
    #
    # Gets us this instead:
    #    https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/os/repodata/repomd.xml: [Errno 14] curl#58 - "unable to load client key: -8178 (SEC_ERROR_BAD_KEY)"
    #
    # Even running the subscription-manager manually from the script
    # doesn't seem to help, even though it normally works from the
    # command line
    #
    # subscription-manager register --username='__rhn_user__' --password='__rhn_pass__'
    # subscription-manager attach --auto
    #
    # To use: https://access.redhat.com/solutions/641193
    # Short version, log in as cloud-user
    #
    # Bugs filed:
    # - https://bugzilla.redhat.com/show_bug.cgi?id=1340323

    openstack image create --container-format bare --disk-format qcow2 --public --file rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2 ha-guest

elif [ -e ${image_target} ]; then
    echo "Using pre-prepared RHEL guest with HA-Addon"
    openstack image create --container-format bare --disk-format qcow2 --public --file ${image_target} ha-guest

elif [ -e rhn.pass -a -e rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2 ]; then
    # Since the above doesn't work, pre-install the packages instead
    echo "Adding HA-Addon packages to RHEL guest"
    rsync -av --progress rhel-guest-image-${image_version}-${image_date}.0.x86_64.qcow2 ${image_target}

    # We need the yet-to-be-released RHEL 7.3 version though, so grab an unofficial rebuild
    cat <<EOF>guestfs.repo
[libguestfs]
name=GuestFS Tools
baseurl=http://people.redhat.com/abeekhof/libguestfs/
gpgcheck=0
EOF
    sudo cp -f guestfs /etc/yum.repos.d/
    sudo sudo yum update -y libguestfs-tools-c
    
    virt-customize  -v -a ${image_target} \
		    --sm-credentials 'rhn-engineering-abeekhof:file:rhn.pass' \
		    --sm-register --sm-attach auto \
		    --install "pcs,pacemaker,corosync,fence-agents-all,resource-agents,ntp,gcc" \
		    --sm-unregister \
		    --selinux-relabel

    openstack image create --container-format bare --disk-format qcow2 --public --file rhel-ha-guest-${image_version}.qcow2 ha-guest

else
    echo "Creating a CentOS ${image_version} based guest"
    # Log into booted instances as user 'centos'
    cat<<EOF>no-selinux.sh
setenforce 0
sed -i s/enforcing/permissive/ /etc/selinux/config
EOF
    virt-builder centos-${image_version} --format qcow2 --install "cloud-init" --selinux-relabel
    #--run ./no-selinux.sh
    openstack image create --container-format bare --disk-format qcow2 --public --file centos-${image_version}.qcow2 ha-guest
fi
