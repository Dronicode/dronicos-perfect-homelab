# Dronico's Perfect Docker

There are two main ways to set this up- standalone Docker, or Swarm Mode.  
In **Standalone docker**, each host is individual and unrelated to the others. A single Portainer instance can be used, with the others reporting to it via Edge Agent. Traefik will need to be installed on each device though, because all containers need to exist on the same docker network for it to work.  
This is where **Swarm Mode** comes in. Rather than dealing with individual hosts, they're all joined as nodes to a single cluster with one being a manager node. Resources like networks and mounted volumes can be shared among the whole cluster. Containers are deployed in stacks via the manager which then runs them on whichever node(s) are available. If a node goes down everything running on it will immediately be run on another host with minimal interruption.  
Aside from gaining various benefits including high-availability services, Swarm Mode will enable a single instance of Traefik to handle all containers from all hosts.

Requirements:

- Basic Linux skills
- 3 servers to run in a cluster

# Preparation

## Install Docker

**_Raspberry Pi OS (Debian)_**  
Update system.  
`sudo apt-get update && sudo apt-get upgrade`  
Install Docker Engine, containerd, and Docker Compose.  
`sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`

**_Arch_**  
Update system.  
`sudo pacman -Syu`  
Install Docker Engine, containerd, and Docker Compose.  
`sudo pacman -S docker docker-compose`

**_After install_**  
Check the versions are correct.  
`sudo docker version`  
`sudo docker-compose version`

Verify it works by running a test image.  
`sudo docker run hello-world`

# Provision a swarm

**_[On the node which will be the manager]_**  
Initialize a swarm, advertising it at the local IP of the manager node.  
`sudo docker swarm init --advertise-addr <MANAGER-IP>`

Output will show something like this.

> To add a worker to this swarm, run the following command:  
> `docker swarm join \`  
> `--token <TOKEN> \`  
> `<IP>:2377`

Run it on **_[all the other nodes]_**.

Confirm all nodes are joined to the swarm.  
`sudo docker node ls`

**Going forward, all commands need to be run on the manager node only, unless specified.**

## Add labels to nodes to define their role

`sudo docker node update --label-add <LABEL> <HOSTNAME>`  
Eg: "sudo docker node update --label-add media epic-media-server" (give the label 'media' to the worker who's hostname is 'epic-media-server')

# Persistent storage

Docker containers are stateless, they have no access to the host's file system by default. The services inside containers have no access to configuration files they need, and any output files disappear as soon as the container is stopped because. To provide needed configuration files and keep any output data, folders in the host filesystem need to be linked to the container filesystem. This gives it persistent storage. There are two different ways to provide persistent storage to a container- volumes, and bind mounts.

Docker volumes are named objects managed by the docker engine and stored in /var/lib/docker/volumes/. They can be referred to by name and mounted in multiple containers at once. Bind mounts can be configured to directly reference any specific files or folders in the host filesystem which already exist and mount them to the container. Swarm mode is a little more complex, storage must be shared with all nodes so containers can mount the needed files on any node in the cluster. If using volumes, certain volume drivers like NFS and SSHFS can be used to share a volume with other nodes. This has some advantage for convenience but all the files remain on a single machine which then acts as a point of failure for all the others. Bind mounts do not have any built in solution for swarms, so the architect has to provide their own. A common 3rd party solution is to use glusterFS volumes which is more complex to set up than docker volumes but distributes the volume to all nodes resulting in a high availbility platform using replication.

Although docker volumes are powerful and convenient, we want to keep all our data in one single location and already will need to use bind mounts for many config files so it makes sense to use it for everything and also benefit from high availability and a lower chance of data corruption with glusterFS.

## Prepare hostname resolution

Pihole will be used for DNS, but it will be containerized and the nodes need to find each other even when all containers are offline or don't exist yet. The simplest way to take care of this is adding a list of host addresses to the hosts file.

**_[On every node]_**  
Edit the hosts file.  
`sudo vim /etc/hosts`

Fill out the following list of all your hosts and add it to the hosts file on every node.

> 192.168.?.? hostname1  
> 192.168.?.? hostname2  
> 192.168.?.? hostname3

## Install GlusterFS

**_Raspberry Pi OS (Debian)_**  
`sudo apt install glusterfs-server -y`

**_Arch_**  
`sudo pacman -S glusterfs`

If you want to confirm the installation, check the version.  
`glusterfs -V`

Enable the service and start it immediately (using the --now flag).  
`sudo systemctl enable --now glusterd`

## Peer the nodes

Important note, glusterFS needs at least three nodes to work. If there are only two then it runs the risk of getting a split-brain where it can't tell which version of a file is correct.

Add all the nodes to the glusterFS pool. Add a line for each node.  
`sudo gluster peer probe [peer1-hostname]; sudo gluster peer probe [peer2-hostname];`  
_If it fails with errors that the endpoint is not connected make sure that the hosts file is set correctly. If that is not the issue then a firewall on the endpoint may be blocking traffic and need ports opened._

Confirm all the peers have been added:  
`sudo gluster pool list`  
or  
`sudo gluster peer status`

## Set up the glusterFS volume dirs

A glusterFS volume is a logical collection of bricks, which is the term used for a storage directory. Two directories are used for managing this.

- The volume - In this dir glusterFS keeps lots of metadata for monitoring whatever happens to the bricks. We don't need to touch anything in there, glusterFS manages this itself when a volume is started.
- The brick - This dir is storage for whatever is getting replicated. Although a folder is created, glusterFS is treated as an external device and will need to be mounted to the filesystem to operate.

**_[Create both folders on all nodes]_**

First, we create the volume folder.  
`sudo mkdir -p /gluster/volumes/`

Second, we create the storage folder. This is the mountpoint where gluster will be mounted to the filesystem. This will be referred to as the DOCKERDIR because all docker-related files go inside it. Later we'll prepare some subfolders for organizing the contents.  
`sudo install -m 0774 -o root -g docker -d /opt/docker && sudo chmod g+s /opt/docker/`
_Note: Use the install command to easily set the folder owner as root and the group as docker with 774 permissions. This is because we don't want anything but docker to be able to access and modify the files. We also use chmod to set the bit so any subfolders will automatically also belong to the docker group._

This ownership setting will also be replicated to all nodes too, using docker's group ID (GID). Specifically, the GID of the docker group on the node where the command is run. A potential issue can arise if the docker group has a different ID on other nodes. If this happens, the folder permissions on them will show the GID but not be associated with Docker and then Docker won't be able to access the folder.  
To check this, look at the group file on the manager node.  
`cat /etc/group`  
You'll find something like this: "docker:x:[GID]:". The number is the GID which owns DOCKERDIR. Run the same command on all the nodes and make sure docker also has the same GID on all of them.  
If any are different, change them to match (Change the number as needed).  
`sudo groupmod -d [GID] docker`  
_**Warning:** Make sure that GID is not already in use. otherwise it can cause problems. Change that one first and then the one for docker. Also note all of the original IDs in case you have to change one back to try again._

You may also find that you can't access DOCKERDIR any more if you're not working as root. Add your user to the docker.  
`sudo usermod -aG docker [username]`

## Create the glusterFS volume itself.

Three replicas are needed for high availbility and data consistency. This can be done with only two replicas but runs the risk of "split-brain" errors. If using only two nodes, see notes below.

**_[Only run this on the manager node]_**  
`sudo gluster volume create dockerdir replica 3 [hostname1]:/gluster/volumes/ [hostname2]:/gluster/volumes/ [hostname3]:/gluster/volumes/`  
This creates a replicated volume called 'dockerdir' at the location '/gluster/volumes/' on each node.

**For clusters with two nodes:** _An arbiter can be used to prevent split-brain errors but should also be put on a third node. It is possible to work around this by adding the arbiter as a second replica on one of the nodes. This solution works but is only a workaround and should be considered a temporary measure as it introduces other potential faults to the system._  
_The command is almost the same as before with a couple extra bits. Note that the third replica will be the arbiter and not a real replica._  
`sudo gluster volume create dockerdir replica 3 arbiter 1 [hostname1]:/gluster/volumes/ [hostname2]:/gluster/volumes/ [hostname1]:/gluster/volumes/arbiter/ force`  
_Don't forget to create a dir for the arbiter brick. It doesn't need to have all the extra permissions etc set because that will be inherited from the main one._  
`sudo mkdir -p /opt/docker-arbiter/`

Start the volume.  
`sudo gluster volume start dockerdir`

Now that the volume has been created and started, it still needs to be mounted to the host filesystem. We'll also add it to the fstab file so it can be automounted every time the host starts up.

## Mount the volume to the host filesystem

Add it to the fstab file for automounting.  
_Note, editing the fstab file wrong can mess up the boot system. Make sure to copy it exactly and not change anything else._  
`sudo vim /etc/fstab`

At the bottom copy this onto the file.

> \# glusterFS mount  
> localhost:/dockerdir /opt/docker glusterfs defaults,\_netdev,backupvolfile-server=localhost 0 0

After editing fstab the systemctl daemon needs to be reloaded.  
`systemctl daemon-reload`

Now test fstab without applying it.  
`sudo mount --fake -av`  
The command `mount -a` will mount all filesystems in fstab which are not mounted yet. If it returns no error then it probably worked. Before that, we want to test it. the flag `--fake` means it us run but not applied. the flag `-v` will give verbose output.  
If it shows "/opt/docker : successfully mounted" with no errors then its ready to mount.

Mount everything in fstab with this command.  
`sudo mount -a`

Check that the filesystem has been mounted.  
`df -h`  
If you see a line like this at the bottom then it worked:

> localhost:/dockerdir 466G 230G 236G 50% /opt/docker

## File structure - DOCKERDIR

DOCKERDIR will store many files for managing containers, providing configuration to services, and storing output. It's always a good idea to keep all of this well organized and consistent for the sake of simplifying maintenance, and for the glusterFS volume it needs to be kept in one place.  
Here is a rundown of an optimal folder structure.

**/opt/docker/..** = _(The DOCKERDIR. Contains docker-compose files and .env)_  
**../config** = _(Config files, docker builds, custom scripts, and .env files)_  
**../logs** = _(Log files from all containers and services)_  
**../private** = _(Anything secret like SSL certificates and passwords)_  
**../services** = _(Persistent appdata for all containers)_

When mounting these, never mount an entire folder. That will provide access for all the unrelated files to the container, which is bad practice. Rather, mount specific files and only folders when all the contents of the folder are relevant.

Create the folders and set stricter permissions for the private folder so only root has access.  
`sudo install -m 0774 -d /opt/docker/{config,logs,services}`
`sudo install -m 0770 -d /opt/docker/private`

# Networking

Networks can be created within compose files but its better to start them separately so they remain available to other containers even if that stack is stopped.

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
`macvlan_01`

## Check networks

Confirm all networks are created:  
`sudo docker network ls`

# Environment variables

A lot of information in docker compose files is repeated many times or sensitive. Instead of updating each reference every time something gets changed or redacting it all before pushing it to github, a .env file is used to handle this data.  
Before using swarm mode, I had to maintain a different version of .env for each host with the contents relevant to that host's containers. One advantage now is that only a sinlge .env is needed to provide variables for them all.

Create it then paste in everything from the provided example.env, editing as needed.  
`sudo vim /opt/docker/.env`

# Deployment

Docker swarm works a lot like docker compose where a single command is used to deploy containers from a .yml script. A stack is a group of services all run as a collection. Usually stacks are grouped by purpose, for instance a stack for hosting a site might include the webserver and the database. Its mostly compatible with compose files so usually stacks are deployed from docker-compose.yml files but sometimes people use docker-stack.yml instead.

Before deploying any stack, we need to add the prerequisite folders/ files to DOCKERDIR so they will be available for the bind mount. After that, the command syntax for deploying a stack is `sudo docker stack deploy -c [filename] [stack name]`.

The first and most important stack to deploy is the core stack, comprising of Traefik and Portainer which will form the core infrastructure which manage all the other services in the cluster. After that, the rest are optional as needed.

## Stack: Core

### Dockerdir prep

Add folders for Traefik config and logs.  
`sudo install -m 0774 -d /opt/docker/{config/{traefik,/traefik/dynamic-configs},/logs/traefik}`

Traefik is configured using a combination of static and dynamic configs, each of which can be included in files, or written directly into the docker compose file. Here, the static config is 100% in file form (it cannot be mixed and matched with file and docker flags), while the dynamic configs are mostly defined in the compose files in the 'labels' section of each service but also some dynamic configs are used for middlewares etc.

Copy everything from the /config/traefik folder in the repo into DOCKERDIR. It'll be something like this.  
$DOCKERDIR/config/traefik/traefik.yml  
$DOCKERDIR/config/traefik/dynamic-configs/<traefik-dynamic and multiple other .yml files>

Traefik uses Lets Encrypt, a service which provides free SSL certificates for domains to route all the services with https rather than http. Everything is configured already, just create the file acme.json to contain the certificates. This is very sensitive information which must be kept safe so we'll add very strict permissions to it.  
`sudo install -m 600 /dev/null /opt/docker/private/acme.json`  
Sometimes it throws an error if the file is completely blank so edit it with {} to make the json work.  
`echo "{}" | sudo tee /opt/docker/private/acme.json`

Traefik can also provide basic HTTP authentication. Later on it'll be made redundant by using a better auth middleware, but it doesn't hurt as a place to start.  
Create a password file.  
`touch /opt/docker/private/.htpasswd`  
The password needs to be encrypted using the .htpasswd command. This depends on an apache package, so install it.  
**_Raspberry Pi OS (Debian)_**  
`sudo apt install apache2-utils`  
**_Arch_**  
`sudo pacman -S apache`  
When installed, edit the following command and run it.  
`echo $(htpasswd -nb <username> <strongpassword>) | sed -e s/\$/\$\$/g`  
The output will look like <username>:$<random letters and numbers>$. Paste that into the .htpasswd file.

That's Traefik's folders prepared, Portainer is easier. It just needs one data folder.  
`sudo install -m 0774 -d /opt/docker/services/portainer/data`

One line in Traefik's config in docker-compose.yml needs to be there the first time it runs, but isn't needed after. The line is this:  
_#- 'traefik.http.routers.traefik-rtr.tls.certresolver=${CERT_RESOLVER}'_  
This is where Traefik will contact the servers and obtain a wildcard certificate for the domain. Remove the initial # to uncomment it.

`sudo docker stack deploy -c core.docker-compose.yml core`

Check if it worked.
`docker stack services core`
