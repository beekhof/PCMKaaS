# Concept

Create/manage pacemaker clusters inside OSP instances/tenants.
Start with how OSPd deploys the stack existing stack with Heat and try to make it more generic.
Provision new tennant(s), network(s) and potentially even LBs to provide isolation and also ensure that the environment is HA-freindly

# Considerations

puppet? move to ansible?

# Scenarios

1. Basic (Small) cluster
  - 2 to 16 nodes
  - plain and simple pacemaker cluster
  - 2 networks: 1 for internal pcmk / corosync heartbeat, 1 for VIPs and services (on internal network).
    Config should allow to create N VIPs that maps outside world to inside
  - Cinder volume for shared storage?
    - Available since Liberty, depending on driver.
    - Will need to look into runtime probing to check, we will need a RAs for this one
  - Limited set of options
    - VIPs mapping
    - size of storage
    - size of cluster (nodes)
    - instance size defined by template (cpu/ram/etc)
    - image pre-loaded with all packages

2. Medium scalable cluster
  - 3 to 32 nodes: 2-16 cluster nodes 1-16 load balancers in front
  - 2 separate pacemaker clusters, one for the LB and one for the services
  - 4 networks
    - 2 for internal pcmk /corosync heartbeat (one for each cluster)
    - 2 for services 
      - one on the LB side exposed to the outside world, and
      - one between LB and the pacemaker cluster for services
  - Cinder volume for shared storage?
  - Limited set of options:
    - VIPs mapping
    - Size of storage
    - Size of cluster (nodes)
    - instance size defined by template (cpu/ram/etc)
    - image pre-loaded with all packages

3. Medium scalable cluster with storage cluster
  
  Same as 2. but with an extra 3-5 node cluster to provide HA storage via NFS/samba

4. Large scalable cluster
  - 6 nodes to N: 1 corosync/pacemaker cluster of size N, with M pacemaker_remote managed nodes.
  - 3/4 networks: 
    - 1 for the internal pacemaker / corosync heartbeat / pacemaker_remote
    - 1 for the services, and
    - 1 between the LB and services
  - services defined / isolated by node roles
  
    Same approach as compute nodes for Instance HA.
    It would allow us to have "fake clusters" of one remote node in case of major failures as long as the main cluster is operational.
  
  - All managed by central cluster
  
    Potentially this would become the CaaS API entry point
  
  - Cinder volume for shared storage?
  - Full set of options for sizing, vip mappings, number of clusters/roles etc.
    - VIPs mapping
    - size of storage
    - size of cluster (nodes)
    - instance size defined by template (cpu/ram/etc)
    - image pre-loaded with all packages

# Factoids

sgotliv says:

        you can run "cinder show <volume_id>" and search for the multiattach property.
        it requires first to create the volume and then look for attr.
        most of the driver do support it, Ceph - doesn't, some needs to be specifically configured in cinder.conf 
