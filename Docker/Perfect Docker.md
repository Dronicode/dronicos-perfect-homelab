# Dronico's Perfect Docker

There are two main ways to set this up- standalone Docker, or Swarm Mode.  
In **Standalone docker**, each host is individual and unrelated to the others. A single Portainer instance can be used, with the others reporting to it via Edge Agent. Traefik will need to be installed on each device though, because all containers need to exist on the same docker network for it to work.  
This is where **Swarm Mode** comes in. Rather than dealing with individual hosts, they're all joined as nodes to a single cluster with one being a manager node. Resources like networks and mounted volumes can be shared among the whole cluster. Containers are deployed in stacks via the manager which then runs them on whichever node(s) are available. If a node goes down everything running on it will immediately be run on another host with minimal interruption.  
Aside from gaining various benefits including high-availability services, Swarm Mode will enable a single instance of Traefik to handle all containers from all hosts.

## Install Docker

**TODO - install instructions**

# Volumes and data management

## DOCKERDIR

A lot of files are used for configuring and deploying stacks of docker containers and services. Those also produce data which we want to keep. It's a good idea to keep all of these files well organized in a single location. This folder containing everything will be referred to as DOCKERDIR and also used as an environment variable to be referenced more easily in scripts.

This directory structure below is helpful to keep everything well organized and easy to manage:

**/opt/docker/..**  
**../config** = _(Config files, docker builds, custom scripts, and .env files)_  
**../logs** = _(Log files from all containers and services)_  
**../private** = _(Anything secret like certificates and passwords)_
**../services** = _(Persistent appdata for all containers)_

The script below will create the folders and set their permissions appropriately. We only need this on the host which will be the manager node. Alternatively, a separate file server can be used.

`sudo mkdir -p /opt/docker/{services,config,logs,private}`  
`sudo chmod 764 -R /opt/docker/`  
`sudo chmod 600 /opt/docker/private`  
`sudo setfacl -Rdm g:docker:rwx /opt/docker/`

All of the docker-compose.yml files will live in the root of DOCKERDIR and be easily accessible.

## Persistent volumes

Docker containers are stateless. This means that all the data and everything inside a container disappears as soon as it is stopped. In order to keep that data, folders need to be mounted between the host filesystem and the container. This is called persistent storage.

In swarm mode any container might run on any node, but they all need access to the same volumes in order to keep the data and configurations consistent across the cluster. To achieve this, the DOCKERDIR will be mounted as a distributed volume and replicated to all nodes using glusterFS.

**TODO - volume mounting**

# Provision a swarm

On the node which will be the manager, run:  
`docker swarm init --advertise-addr <MANAGER-IP>`

Output will show something like:

> To add a worker to this swarm, run the following command:  
> `docker swarm join \`  
> `--token <TOKEN> \`  
> `<IP>:2377`

The unique token can be used for joining worker nodes. Don't change anything, run it on all worker nodes.

Confirm all nodes are connected  
`sudo docker node ls`

Going forward, all commands need to be run on the manager node only.

## Add labels to nodes to define their role

`docker node update --label-add <LABEL> <HOSTNAME>`  
Eg: "docker node update --label-add media epic-media-server" (give the label 'media' to the worker who's hostname is 'epic-media-server')

# Networking

Networks can be created within compose files but its better to start them separately so they remain available to even if the compose file is taken down.

## Proxy network

Traefik uses different providers to handle services (in this case, docker containers). The docker provider is what lets it manage docker containers using labels in the compose files. For that to work, Traefik needs to be on the same docker network as those containers in order to see them.

In docker's normal mode, networks cannot be shared between hosts so Traefik would need to use a file provider to manage services on other hosts using a workaround with load balancing flags and assigning static IPs to all containers which requires a lot of unnecessary effort. With docker in swarm mode, one network can be shared between all hosts simplifying the process significantly.

This script should be run on the manager node. will create the network called proxy_traefik and specify a subnet for it.

`sudo docker network create \`  
`--driver=overlay \`  
`--subnet=172.20.20.0/24 \`  
`proxy_traefik`

## Macvlan network

Pihole has special networking needs in order to perform its DNS functions correctly, and also needs to exist within the primary network. All of this can be met using macvlan.

In docker we can create a macvlan network over the primary network so that the IP of anything in it also appears to belong to the other one. The issue here is that the docker engine acts as its own DHCP server and will potentially clash with the main DCHP server when assigning IPs. A workaround for this is to limit the macvlan to a very small IP range and then reserve that range on the router.

For example, if the primary network is 192.168.0.0/24 with the gateway at 192.168.0.1, then I might shave off the last few addresses from the end by reserving the address range .252-.255. Then the macvlan can be created in subnet 192.168.0.252/30 which fills that range. This gives space for 2 possible hosts in the macvlan (.253 and .254) which is all it needs.

The same process can be repeated for a second pihole on another host using the next block of addresses, subnet .248/30.

You also need to check which network interface device is used on the host where the network will be created. Usually this is eth0.

Because of this requirement, the pihole container must be constrained to only run on the node(s) where such a network has been created.

`sudo docker network create \`  
`--driver=macvlan \`  
`--subnet=192.168.0.252/30 \`  
`-o parent=eth0 \`  
`macvlan_[hostname]`

# Specific service preparation

## Traefik preparation

Lets Encrypt is a service which provides free SSL certificates for domains. This can be integrated with Traefik to make sure that all the services it routes use https rather than http.
Create acme file for LE SSL certs and secrets files

`sudo install -m 600 /dev/null /opt/docker/private/acme.json`

## Portainer configuration

`sudo docker volume create portainer_data` # Only needed for Portainer manager

# Deployment

A stack is the swarm version of a compose file.
