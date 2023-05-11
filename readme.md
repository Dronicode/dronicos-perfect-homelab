# Dronico's Perfect Homelab

I'm building a homelab. As my skills improve and as I can add or upgrade hardware, the homelab continues to evolve and grow.
This repo contains everything that I do for each stage of this project.

---

## Installation

As I add new devices to the lab I want all hosts to be exactly identical in their core installation with only minimal differences where necessary for each use case. Likewise, if any server is replaced, I should be able to reinstall the replacement to be identical to its predecessor.

All Raspberry Pi devices have PiOS installed, and everything with an x86_64 processor is running Arch. This was selected for maximum control over configuration and included packages.

**TODO:** _Switch to using the ARM version of Arch for all the Pis for more consistency._

In the Install folder is guides with all the steps for installation of these servers to configure them the same each time.

**TODO:** _Learn to automate installation from custom ISO to start it off easily._

---

## Configuration

I like to tinker and personalize all my configurations. All of the config files for everything not in a container go here and are organized according to the directory where the files belong in Linux.

List of configs:

- bash
- neofetch
- samba
- shell aliases and other customizations
- starship
- qBittorrent (Deprecated, moving to docker)
- zshell

**TODO:** _Create scripts which can automatically deploy all the configs in one go by symlinking each file to the real location where it goes._

---

## Containerization

Everything that can be containerized, should be.

List of apps and services:

Container management

- Traefik proxy
- Portainer
- Portainer edge agent
- Docker garbage collector
- Dozzle
- Watchtower

Networking

- Pihole (Or AdGuard Home?)
- Dhcp-helper
- Unbound

Media

- Jellyfin

**TODO:** _Add all the other planned containers._
