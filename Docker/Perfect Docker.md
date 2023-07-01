# Dronico's Perfect Docker

There are two main ways to set this up- standalone Docker, or Swarm Mode.  
In Standalone docker, each host is individual and unrelated to the others. A single Portainer instance can be used, with the others reporting to it via Edge Agent. Traefik will need to be installed on each device, but it is possible to set up a single Traefik instance using file providers.

## Create DOCKERDIR

This dir structure is helpful to keep all docker files and container application data.

- app = appdata for each container
- config = all config files, docker builds, custom scripts, and .env files
- logs = keep all logfiles in one place
- private = anything secret like certificates and passwords

Aside from creating the folders,

`sudo mkdir -p /opt/docker/{app,config,logs,private}`  
`sudo chmod 764 -R /opt/docker/`  
`sudo chmod 600 /opt/docker/private`  
`sudo setfacl -Rdm g:docker:rwx /opt/docker/`

## Create acme file for LE SSL certs and secrets files

`sudo install -m 600 /dev/null /opt/docker/private/acme.json`

## Create networks

Create networks outside of compose files so they remain even if the compose file is taken down.

### Proxy network

Traefik uses different providers to handle endpoints (in this case, docker containers). While the file provider requires hardcoding internal IPs for each endpoint, the docker provider instead uses the name of a docker network and allows Traefik to dynamically identify all the containers on that network.  
Ideally, one single docker network would be created as an overlay between all hosts for Traefik to easily use the Docker Provider for all containers on all hosts. This doesn't seem to be possible without using swarm mode though, so instead a network for each host will be created.  
As Traefik won't be able to see the networks for other hosts, we'll use them for specifing an IP for each container and let Traefik find them using the file provider.

This will be used by traefik and all containers from the same host.  
`sudo docker network create \`  
`--driver=bridge \`  
`--attachable \`  
`--subnet=172.20.20.0/27 \`  
`proxy_traefik_ama`

It would probably be ideal to have all hosts share a proxy network but I haven't managed to figure that out yet so we'll create one for each host.

`sudo docker network create \`  
`--driver=bridge \`  
`--attachable \`  
`--subnet=172.20.20.32/27 \`  
`proxy_traefik_ame`

### Macvlan network

This is a special network needed by pihole.  
This needs to be included in the primary network for pihole to work. The problem here is that the docker engine acts as its own DHCP server, so if you give the same IP range to this and the real DHCP server, you run the risk of these trying to assigning the same address to different devices.

My solution is to trick it by providing the macvlan with just a small subnet within the same IP range as the primary network, then reserving those addresses on the real DHCP server.

For example, if the primary network is 192.168.0.0/24 with the gateway at 192.168.0.1, then I might shave off the last few addresses from the end by reserving the address range .252-.255. Then the macvlan can be created in subnet 192.168.0.252/30 which fills that range. This gives space for 2 possible hosts in the macvlan (.253 and .254) which is all it needs.

The same process can be repeated for a second pihole on another host using the next block of addresses, subnet .248/30.

You also need to check which network interface device is used on the host where the network will be created. Usually this is eth0.

`sudo docker network create \`  
`--driver=macvlan \`  
`--subnet=192.168.0.252/30 \`  
`-o parent=eth0 \`  
`macvlan_[hostname]`

## Create volumes

`sudo docker volume create portainer_data` # Only needed for Portainer manager

## Portainer Edge

Portainer edge is tricky to integrate correctly with traefik.

The Edge Key needs to be modified as per these instructions:
https://github.com/portainer/portainer-compose/issues/24#issuecomment-942389178
https://github.com/portainer/portainer/issues/6251

Use this for decode/ encode: https://www.base64encode.org/

Additional notes and clarifications:

- When creating the environment on Portainer, make sure to leave it with the default target address of portainer.\*.
- tls.certresolver isn't needed in the flags, just tls=true, if wildcard SSL certs are used.

Here's an example of a working string:
https://portainer.example.net|https://edge.example.net|abcdefghijklmnopqrstuvwxyz1234567890=|2

# Alternate: Docker Swarm Mode (Incomplete)

**Missing: How to handle persistence and mounting volumes.**
**Missing: Details on stack preparation and deployment.**

## Provision a cluster (swarm)

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

## Create an overlay network

This network will enable conrainers on all nodes to communicate together. It will also be Traefik's proxy network.

`sudo docker network create --driver=overlay proxy_traefik`

Optional: define specific subnet for the overlay network

`sudo docker network create \`  
`--driver=overlay \`  
`--subnet=172.20.20.0/24 \`  
`proxy_traefik`

## Deploy stacks

A stack is the swarm version of a compose file.
