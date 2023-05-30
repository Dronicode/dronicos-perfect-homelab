# Dronico's Perfect Docker

**TODO:**

_- Add the other networks- .128/26, .192/26_

# Create DOCKERDIR

`sudo mkdir -p /opt/docker/{app,config,custom,logs,private,shared}`
`sudo setfacl -Rdm g:docker:rwx /opt/docker/`

# Create acme file for LE SSL certs and secrets files

`install -m 600 /dev/null /opt/docker/config/acme.json`
`touch /opt/docker/logs/traefik.log`

# Create networks

`sudo docker network create \`  
`-d ipvlan --attachable \`  
`--subnet=172.20.20.64/26 \`  
`-o parent=eth0 -o ipvlan_mode=l3 \`  
`dronilab01b`

`sudo docker network create \`  
`-d ipvlan --attachable \`  
`--subnet=172.20.20.128/26 \`  
`-o parent=eth0 -o ipvlan_mode=l3 \`  
`dronilab01c`

`sudo docker network create \`  
`-d ipvlan --attachable \`  
`--subnet=172.20.20.192/26 \`  
`-o parent=eth0 -o ipvlan_mode=l3 \`  
`dronilab01d`

# Create volumes

sudo docker volume create portainer-data # Only needed for Portainer manager

## Test container

`sudo docker run -itd --rm \`  
`--net=dronilab01b \`  
`--ip=172.20.20.69 \`  
`--name=ipv1 traefik/whoami`

sudo docker run -itd --rm --net=dronilab01-vlan --name=ipv1 traefik/whoami
