# Dronico's Perfect Arch Install

`This is code to be run line by line in the terminal.`

> This is input to be entered in an editor like vim.

**TODO:**

_- Add steps for adding in all other config files_  
_- Add steps for Docker_  
_- Add steps for the following:_  
https://wiki.archlinux.org/title/fan_speed_control  
https://wiki.archlinux.org/title/CPU_frequency_scaling  
https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate

---

## Preparation

## _Install media_

Use a tool like Raspberry Pi Imager to make a bootable USB drive with the latest Arch ISO.  
Startup the machine with the USB drive in it, and boot from that.

## _Initial tests_

When the bootable ISO has started, these tests are useful quick checks to confirm all is as expected.

`\# Confirm internet connection`  
`ping -c 3 1.1.1.1`
`\# Confirm all drives are connected`  
`lsblk`  
`\# Confirm clock is synced`  
`timedatectl status`

## _Format and partition drives_

`gdisk /dev/sda`

> \# View then clear all current partitions  
> p  
> o  
> y  
> \# Create boot partition  
> n  
> \<default>  
> \<default>  
> +512M  
> ef00  
> c  
> BOOT  
> \# Create root partition  
> n  
> \<default>  
> \<default>  
> \<default>  
> \<default>  
> c  
> 2  
> ROOT  
> \# View then save new partition table  
> p  
> w  
> y

`mkfs.vfat -F32 -n BOOT /dev/sda1`  
`mkfs.btrfs -L ROOT /dev/sda2`

## _Mount filesystem_

`mount /dev/sda2 /mnt`  
`cd /mnt`  
`btrfs su cr @`  
`btrfs su cr @cache`  
`btrfs su cr @home`  
`btrfs su cr @images`  
`btrfs su cr @log`  
`btrfs su cr @snapshots`  
`cd`  
`umount /mnt`  
`mount -o compress=zstd:1,noatime,subvol=@ /dev/sda2 /mnt`  
`mkdir -p /mnt/{boot,home,.snapshots,var/{cache,log,lib/libvirt/ images}}`  
`mount -o compress=zstd:1,noatime,subvol=@cache /dev/sda2 /mnt/ var/cache`  
`mount -o compress=zstd:1,noatime,subvol=@home /dev/sda2 /mnt/ home`  
`mount -o compress=zstd:1,noatime,subvol=@images /dev/sda2 /mnt/ var/lib/libvirt/images`  
`mount -o compress=zstd:1,noatime,subvol=@log /dev/sda2 /mnt/ var/log`  
`mount -o compress=zstd:1,noatime,subvol=@snapshots /dev/sda2 / mnt/.snapshots`  
`mount /dev/sda1 /mnt/boot/`  
`lsblk`

---

## Installation

## _Minimal base install_

`#Configure reflector, maybe not needed yet?`  
`reflector --country Czechia,Germany,France --latest 5 --sort rate --save /etc/pacman.d/mirrorlist`  
`pacman -Syy`  
`pacstrap -K /mnt base linux linux-firmware reflector vim`  
`genfstab -U /mnt >> /mnt/etc/fstab && vim /mnt/etc/fstab`  
`arch-chroot /mnt`

## _Localization_

`ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime`  
`hwclock --systohc --utc`  
`vim /etc/locale.gen`  
`en_GB.UTF-8`  
`locale-gen`  
`echo LANG=en_GB.UTF-8 > /etc/locale.conf && echo KEYMAP=cz-cp1250 > /etc/vconsole.conf`

## _System configuration_

`echo [HOSTNAME] > /etc/hostname`  
`echo 127.0.0.1 localhost > /etc/hosts`  
`echo ::1 localhost >> /etc/hosts`  
`echo 127.0.1.1 [HOSTNAME].[DOMAINNAME] [HOSTNAME] >> /etc/hosts`  
`export VISUAL=vim`  
`# Allow members of group wheel to execute any command`  
`visudo /etc/sudoers`

> %wheel ALL=(ALL:ALL) ALL

`# Misc Options`  
`vim /etc/pacman.conf`

> Color  
> ParallelDownloads = 10

`vim /etc/xdg/reflector/reflector.conf`

> --save /etc/pacman.d/mirrorlist  
> --protocol https  
> --country Czechia,Germany,France  
> --latest 5  
> --sort rate

`reflector --country Czechia,Germany,France --latest 5 --sort rate --save /etc/pacman.d/mirrorlist`  
`pacman -Syy`

## _Install an AUR package manager_

`git clone https://aur.archlinux.org/paru.git`  
`cd paru`  
`makepkg -si`  
`cd ../ && rm -rf paru`  
`paru`

## _Install packages_

`# Prepare package list`  
`cd /`  
`vim dronico-pkglist.txt`

> \# Paste in pkg list. Always use essentials list, add in other lists as needed

`vim dronico-pkglist-aur.txt`

> \# Paste in AUR pkg list. Always use essentials list, add in other lists as needed

`pacman -S --needed - < dronico-pkglist.txt`  
`paru -S --needed - < dronico-pkglist-aur.txt`

---

## System configuration

pkgfile -u

## _Enable system services_

`systemctl daemon-reload`  
`systemctl enable --now firewalld NetworkManager pkgfile-update.timer reflector.timer sshd systemd-boot-update`

## _Set up users_

`passwd root`  
`useradd -mG adm,log,wheel -s /bin/zsh luffy && passwd luffy`

## _Optional: Media server extra steps_

`# Samba configuration`
`vim /etc/samba/smb.conf`

> \# Paste in conf

`firewall-cmd --permanent --add-service=samba`

`# Add a media technical user`
`useradd -rmU mediamgr && passwd mediamgr`  
`gpasswd -a luffy mediamgr # usermod -s /usr/sbin/nologin mediamgr`

`# Mount media drive`  
`lsblk`  
`sudo mkdir -p /vault-102`  
`sudo mount /dev/sd?? /vault-102`  
`sudo chown -R mediamgr:mediamgr /vault-102`  
`sudo chmod -R 744 /vault-102`  
`genfstab -U / | sudo tee /etc/fstab && bat /etc/fstab`

## _Setup Bootloader_

`vim /etc/mkinitcpio.conf`

> MODULES=(btrfs)  
> BINARIES=(btrfs)

`mkinitcpio -p linux`

`ls /sys/firmware/efi/efivars/`  
`bootctl --path=/boot install`  
`vim /boot/loader/loader.conf`

> #timeout 3  
> #console-mode max  
> editor no  
> default arch

`vim /boot/loader/entries/arch.conf`

> title Arch Linux  
> linux /vmlinuz-linux  
> initrd /initramfs-linux.img  
> options root=/dev/sda2 rootflags=subvol=@ rw

`cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf`  
`vim /boot/loader/entries/arch-fallback.conf`

> initrd /initramfs-linux-fallback.img

## _Reboot_

`exit`  
`umount -a`  
`reboot`

## _Shell customization_

See Dronico's Perfect Shell

## _Snapshots_

`sudo paru -S snapper-support`  
`sudo -s && cd /`  
`umount /.snapshots`  
`rm -r /.snapshots`  
`snapper -c root create-config /`  
`btrfs subvol list /`  
`btrfs subvolume delete /.snapshots # if .snapshots is in the list`  
`btrfs subvol list /`  
`mkdir /.snapshots`  
`mount -a && lsblk`  
`btrfs subvol get-default /`  
`# if result is FS_TREE or anythign not ending in "path @"`  
`btrfs subvol lis /`  
`# see ID of line ending "path @"`  
`btrfs subvol set-def [ID] /`  
`btrfs subvol get-default /`  
`vim /etc/snapper/configs/root`

> ALLOW\*GROUPS="wheel"  
> TIMELINE_CREATE="no"  
> TIMELINE_LIMIT_HOURLY="5"  
> TIMELINE_LIMIT_DAILY="5"  
> TIMELINE_LIMIT_WEEKLY="0"  
> TIMELINE_LIMIT_MONTHLY="0"  
> TIMELINE_LIMIT_YEARLY="0"

`chown -R :wheel /.snapshots`  
`cd /`  
`snapper -c root create -d "\*\*\_System Installed*\*\*"`  
`snapper ls`

---

## _References:_

https://www.youtube.com/watch?v=MB-cMq8QZh4  
https://www.youtube.com/watch?v=FFXRFTrZ2Lk
