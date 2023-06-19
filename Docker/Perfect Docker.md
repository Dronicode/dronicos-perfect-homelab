# Dronico's Perfect Docker

**TODO:**

# Create DOCKERDIR

This dir should be created on each host.

- app = appdata for each container
- config = all config files, docker builds, custom scripts, and .env (without secrets)
- logs = keep all logfiles in one place
- private = anything secret like certificates, passwords, and .env (with secrets)

`sudo mkdir -p /opt/docker/{app,config,logs,private}`  
`sudo chmod 755 /opt/docker/`  
`sudo chmod 600 /opt/docker/private`  
`sudo setfacl -Rdm g:docker:rwx /opt/docker/`

# Create acme file for LE SSL certs and secrets files

`sudo install -m 600 /dev/null /opt/docker/config/acme.json`  
`sudo touch /opt/docker/logs/traefik.log`

# Create networks

Create networks outside of compose files so they remain even if the compose file is taken down.

## Proxy network

`sudo docker network create \`  
`-d bridge --attachable \`  
`--subnet=172.20.20.0/26 \`  
`--gateway=192.168.0.1 \`  
`proxy_traefik`

## IPvlan L3 (testing, not for prod)

`sudo docker network create \`  
`-d ipvlan --attachable \`  
`--subnet=172.20.20.64/26 \`  
`-o parent=eth0 -o ipvlan_mode=l3 \`  
`dronilab01b`

# Create volumes

`sudo docker volume create portainer_data` # Only needed for Portainer manager

### Jellyfin configs

`sudo mkdir /opt/docker/app/jellyfin/config`  
`sudo mkdir /opt/docker/app/jellyfin/cache`  
`sudo chown mediamgr:mediamgr /opt/docker/app/jellyfin/config /opt/docker/app/jellyfin/cache`

# Test container

## Docker version

`sudo docker run -itd --rm \`  
`--net=dronilab01b \`  
`--ip=172.20.20.70 \`  
`--name=ipv1 traefik/whoami`

## Docker-compose version

`version: '3.9'`

`networks:`
`dronilab01b:`
`name: dronilab01b`
`external: true`

`services:`
`whoami:`
`image: traefik/whoami`
`container_name: ipv1-test`
`networks:`
`dronilab01b:`
`ipv4_address: 172.20.20.69`
