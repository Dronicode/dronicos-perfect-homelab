# Dronico's Perfect Shell

**TODO:**  
_- Create script to autoinstall all the dotconfigs_

---

## General

## _Update pkgfile_

Needed for bash/zsh completions  
`sudo pkgfile -u`

## _Add progress bars to cp & rm_

`cd ~ && mkdir progress-bar-patch && cd progress-bar-patch`  
`wget http://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz`  
`tar xvJf coreutils-8.32.tar.xz`  
`cd coreutils-8.32`  
`wget https://raw.githubusercontent.com/jarun/advcpmv/master/advcpmv-0.8-8.32.patch`  
`patch -p1 -i advcpmv-0.8-8.32.patch`  
`./configure`  
`make`  
`sudo cp ./src/cp /usr/local/bin/cp && sudo cp ./src/mv /usr/local/bin/mv`  
`cd ~ & rm -rf progress-bar-patch`  
Source https://i12bretro.github.io/tutorials/0778.html

## DOTCONFIG imports

## _Prep some directories_

`mkdir -p $HOME/.config/neofetch, zsh`  
`sudo mkdir -p /etc/neofetch`

Dotconfigs go in the following directories:  
/etc/.sh_alias  
/etc/bash.bashrc  
/etc/neofetch/neofetch  
/etc/zsh/zshkeys  
/etc/zsh/zshrc  
/$HOME/.bashrc  
/$HOME/.config/zsh/.zshrc
/$HOME/.config/starship.toml
/$HOME/.config/neofetch/config.conf

## _Reload shell_

Instead of sourcing the full path for zshell or bash configs, an alias has been added. So only the alias needs to be loaded and then that can be used to source the rest.

`source /etc/.sh_alias`

`srczsh # if you're using zshell`  
`srcbsh # if you're using bash`

---

## _Notes_

Non-Arch references

[Nerd Fonts globall install]  
sudo mkdir -p /usr/local/share/fonts  
sudo curl -fLo "/usr/local/share/fonts/Iosevka Term Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Iosevka/Regular/complete/Iosevka%20Term%20Nerd%20Font%20Complete.ttf  
sudo curl -fLo "/usr/local/share/fonts/Fira Code Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete.ttf
