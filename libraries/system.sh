#!/usr/bin/bash

###################################################################################################
# Handles finding system related information
###################################################################################################

###################################################################################################
# Checks if the system has booted in uefi mode
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   return 0 for UEFI mode enabled, return 1 for UEFI mode disabled
#
# Source:
#   N/A
###################################################################################################
function system::uefi()
{
    local uefi_vars

    uefi_vars=$(efivar -l 2>&1)

    if ! [[ ${uefi_vars:0:13} = "efivar: error" ]]; then
        return 0
    else
        return 1
    fi
}

###################################################################################################
# get the CPU vendor, intel/amd/unknown
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::cpu_vendor()
{
    local intel
    local amd
    local vendor

    intel=$(cat /proc/cpuinfo | grep 'vendor' | grep 'Intel' | uniq | wc -l)
    amd=$(cat /proc/cpuinfo | grep 'vendor' | grep 'AMD' | uniq | wc -l)

    if [[ "${intel}" == "1" ]]; then
        vendor="intel"
    elif [[ "${amd}" == "1" ]]; then
        vendor="amd"
    else
        vendor="unknown"
    fi

    echo "${vendor}"
}

###################################################################################################
# Prompt the user to enter a swap partition size in gibibytes
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::memory_size()
{
    local memory_size
    local memory_raw_size

    memory_raw_size=$(awk '/^Mem/{print $2}' <(free -g))
    memory_size=$((${memory_raw_size}+1))

    echo "${memory_size}"
}

###################################################################################################
# re-initialize arch linux key ring for the installer
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   return 0 for UEFI mode enabled, return 1 for UEFI mode disabled
#
# Source:
#   N/A
###################################################################################################
function system::init_installer_keyring()
{
    system::sync_installer_repositories

    pacman-key --init

pacman -S "archlinux-keyring" << EOF
y
EOF
}

###################################################################################################
# syncs pacman repositories
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::sync_installer_repositories()
{
    pacman -Sy
}

###################################################################################################
# syncs and updates pacman repositories
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::update_installer_repositories()
{
    pacman -Syu
}

###################################################################################################
# syncs pacman repositories on an install
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::sync_repositories()
{
    local root_mount="$1"

    arch-chroot "${root_mount}" "pacman" "-Sy"
}

###################################################################################################
# syncs and updates pacman repositories on an install
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::update_repositories()
{
    local root_mount="$1"

    arch-chroot "${root_mount}" "pacman" "-Syu"
}

###################################################################################################
# enables access to the 32-bit pacman repository "multilib" by changing the pacman configuration
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::enable_multilib()
{
    local root_mount="$1"

    local multilib_line
    local insert_line

    multilib_line=$(grep -n '#\[multilib\]' "${root_mount}/etc/pacman.conf" | cut -d ':' -f1)

    if ! [[ -z "${multilib_line}" ]]; then
        include_line=$((multilib_line + 1))
        sed -i "${multilib_line}c\[multilib\]" "${root_mount}/etc/pacman.conf"
        sed -i "${include_line}cInclude = /etc/pacman.d/mirrorlist" "${root_mount}/etc/pacman.conf"
    fi
}

###################################################################################################
# generates the /etc/fstab file for an installation
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::generate_fstab()
{
    local root_mount="$1"

    # generate fstab file
    genfstab -U -p "${root_mount}" > "${root_mount}/etc/fstab"
}

###################################################################################################
# sets and generates the locale of the system
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::set_locale()
{
    local root_mount="$1"
    local locale="$2"

    local language

    # get the language part of the locale
    language=$(echo "${locale}" | awk '{print $1}')

    # set locale
    echo "${locale}" > "${root_mount}/etc/locale.gen"
    echo "LANG=${language}" > "${root_mount}/etc/locale.conf"

    # generate locale
    arch-chroot "${root_mount}" "locale-gen"
}

###################################################################################################
# sets the host name of the system
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   host name
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::set_hostname()
{
    local root_mount="$1"
    local host_name="$2"

    echo ${host_name} > "${root_mount}/etc/hostname"
}

###################################################################################################
# sets machine's basic information
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   computer name
#   location
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::set_machine_info()
{
    local root_mount="$1"
    local computer_name="$2"
    local location="$3"

    local machine_info_file="${root_mount}/etc/machine-info"

    echo "PRETTY_HOSTNAME=\"${computer_name}\"" > "${machine_info_file}"
    echo "ICON_NAME=computer" >> "${machine_info_file}"
    echo "CHASSIS=desktop" >> "${machine_info_file}"
    echo "DEPLOYMENT=production" >> "${machine_info_file}"
    echo "Location=\"${location}\"" >> "${machine_info_file}"
}


###################################################################################################
# generates the hosts file
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::generate_hosts()
{
    local root_mount="$1"
    local host_name="$2"

    echo "127.0.0.1    localhost" > "${root_mount}/etc/hosts"
    echo "::1          localhost" >> "${root_mount}/etc/hosts"
    echo "127.0.1.1    ${host_name}" >> "${root_mount}/etc/hosts"
}

###################################################################################################
# sets the timezone and hardware clock
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   timezone name in Olson format: America/Chicago
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::set_timezone()
{
    local root_mount="$1"
    local timezone="$1"

    arch-chroot "${root_mount}" "ln" "-s" "/usr/share/zoneinfo/${timezone}" "/etc/localtime"
    arch-chroot "${root_mount}" "hwclock" "--systohc" "--utc"
}

###################################################################################################
# sets the key map of the new system, list of keymaps is from 'localectl list-keymaps'
#
# Globals:
#   N/A
#
# Arguments:
#   name of the key map
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function system::set_key_map()
{
    local root_mount="$1"
    local key_map="$2"

    echo "KEYMAP=${key_map}" > "${root_mount}/etc/vconsole.conf"
}

###################################################################################################
# sets the key map of the installer system, list of keymaps is from 'localectl list-keymaps'
#
# Globals:
#   N/A
#
# Arguments:
#   name of the key map
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::load_key_map()
{
    local key_map="$1"

    loadkeys "${key_map}"
}

###################################################################################################
# configures the sudoers file of the install
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::generate_sudoers()
{
    local root_mount="$1"

    local enabled

    enabled=$(grep "# %wheel ALL=(ALL:ALL) ALL" "${root_mount}/etc/sudoers")

    # make sure if it's already configured, don't attempt to configure again
    if [[ -n "${enabled}" ]]; then
        sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' "${root_mount}/etc/sudoers"
        echo "Defaults rootpw" >> "${root_mount}/etc/sudoers"
    fi
}

###################################################################################################
# configures the sudoers file of the install
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function system::install_unofficial_repositories()
{
    local root_mount="$1"

    local enabled

    # arch zfs repo
    enabled=$(grep "\[archzfs\]" "${root_mount}/etc/pacman.conf")

    # make sure if it's already configured, don't attempt to configure again
    if [[ -z "${enabled}" ]]; then
        echo "[archzfs]" >> "${root_mount}/etc/pacman.conf"
        echo 'Server = https://archzfs.com/$repo/$arch' >> "${root_mount}/etc/pacman.conf"
        arch-chroot "${root_mount}" "pacman-key" "-r" "DDF7DB817396A49B2A2723F7403BD972F75D9D76"
        arch-chroot "${root_mount}" "pacman-key" "--lsign-key" "DDF7DB817396A49B2A2723F7403BD972F75D9D76"
    fi
}

###################################################################################################
# sets the root password of the install
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::set_root_password()
{
    local root_mount="$1"
    local password="$2"

arch-chroot "${root_mount}" "passwd" << chroot_commands
${password}
${password}
chroot_commands
}

###################################################################################################
# enables services on the install
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   enable ssh server, true / false
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::enable_services()
{
    local root_mount="$1"
    local enable_ssh_server="$2"

    arch-chroot "${root_mount}" "systemctl" "enable" "NetworkManager.service"

    if $enable_ssh_server; then
        arch-chroot "${root_mount}" "systemctl" "enable" "sshd.service"
    fi
}

###################################################################################################
# installs the basic packages to make the system
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::install_base_linux()
{
    local root_mount="$1"
    local kernel="$2"
    local cpu_vendor="$3"
    local install_micro_code="$4"

    local micro_code


pacstrap -i "${root_mount}" "base" "base-devel" "openssh" "git" "linux-firmware" "vim" "bash-completion" "networkmanager" "${kernel}" "${kernel}-headers" << base_install_commands
$(echo)
$(echo)
$(echo)
$(echo)
y
y
base_install_commands

if $install_micro_code; then
    micro_code="${cpu_vendor}-ucode"

pacstrap -i "${root_mount}" "${micro_code}" << micro_code_install_commands
$(echo)
$(echo)
$(echo)
$(echo)
y
y
micro_code_install_commands
fi

}

###################################################################################################
# installs the uefi boot loader
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   root partition
#   cpu vendor
#   install micro code true / false
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::install_boot_loader_uefi()
{
    local root_mount="$1"
    local kernel="$2"
    local root_partition="$3"
    local cpu_vendor="$4"
    local install_micro_code="$5"

    local micro_code="${cpu_vendor}-ucode.img"
    local boot_loader_config="${root_mount}/boot/loader/entries/arch.conf"

    # install boot loader
    arch-chroot "${root_mount}" "bootctl" "install"

    # make UEFI boot loader file
    mkdir -p "${root_mount}/boot/loader/entries"
    echo "title Arch Linux" > "${boot_loader_config}"
    echo "linux /vmlinuz-${kernel}" >> "${boot_loader_config}"

    if $install_micro_code; then
        echo "initrd /${micro_code}" >> "${boot_loader_config}"
    fi

    echo "initrd /initramfs-${kernel}.img" >> "${boot_loader_config}"
    echo "options root=PARTUUID=$(blkid -s PARTUUID -o value "${root_partition}") rw" >> "${boot_loader_config}"
}

###################################################################################################
# installs the bios boot loader
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   root partition
#   cpu vendor
#   install micro code true / false
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: make the micro code insertion more robust
###################################################################################################
function system::install_boot_loader_bios()
{
    local root_mount="$1"
    local kernel="$2"
    local root_partition="$3"
    local cpu_vendor="$4"
    local install_micro_code="$5"

    local micro_code="${cpu_vendor}-ucode.img"
    local boot_loader_config="${root_mount}/boot/syslinux/syslinux.cfg"
    local root_part_uuid

    # install bios boot loader, syslinux
pacstrap -i "${root_mount}" "syslinux" << syslinux_install_commands
$(echo)
y
syslinux_install_commands

    # install syslinux MBR
    syslinux-install_update -i -a -m -c "${root_mount}"

    root_part_uuid=$(blkid -s PARTUUID -o value "${root_partition}")

    # configure boot loader entry
    sed -i "s.root=${root_partition}.root=PARTUUID=${root_part_uuid}." "${boot_loader_config}"
    if $install_micro_code; then
        sed -i "55 i \ \ \ \ INITRD ../${micro_code}" "${boot_loader_config}"
        sed -i "62 i \ \ \ \ INITRD ../${micro_code}" "${boot_loader_config}"
    fi

    sed -i "s/linux/${kernel}/g" "${boot_loader_config}"
}

###################################################################################################
# installs the boot loader
# Globals:
#   N/A
#
# Arguments:
#   uefi mode true / false
#   path to where the root partition is mounted, without trailing slash
#   root partition
#   cpu vendor
#   install micro code true / false
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: make the micro code insertion more robust
###################################################################################################
function system::install_boot_loader()
{
    local uefi="$1"
    local root_mount="$2"
    local kernel="$3"
    local root_partition="$4"
    local cpu_vendor="$5"
    local install_micro_code="$6"

    if $uefi; then
        system::install_boot_loader_uefi "${root_mount}" "${kernel}" "${root_partition}" "${cpu_vendor}" "${install_micro_code}"
    else
        system::install_boot_loader_bios "${root_mount}" "${kernel}" "${root_partition}" "${cpu_vendor}" "${install_micro_code}"
    fi
}

###################################################################################################
# Returns a lists groups on the system
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function system::groups()
{
    local groups
    groups=($(cat /etc/group | cut -f1 -d":"))
    sorted=($(printf '%s\n' "${groups[@]}" | sort))
    echo "${sorted[@]}"
}

###################################################################################################
# Creates users
#
# Globals:
#   N/A
#
# Arguments:
#   space separated list, [u1 p1 g1,g2 u2 p2 none]
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function system::create_users()
{
    local root_mount="$1"
    local users=($2)
    local count
    local username
    local password
    local groups

    local username_index
    local password_index
    local groups_index

    count="${#users[@]}"
    ((count=count/3))

    for ((i = 0; i < count; i++)); do
        ((username_index=i*3))
        ((password_index=i*3+1))
        ((groups_index=i*3+2))

        username="${users[username_index]}"
        password="${users[password_index]}"
        groups="${users[groups_index]}"

        if [[ "${groups}" == "none" ]]; then
            arch-chroot "${root_mount}" "useradd" "-m" "-g" "users" "-G" "${groups}" "-s" "/bin/bash" "${username}"
        else
            arch-chroot "${root_mount}" "useradd" "-m" "-g" "users" "-s" "/bin/bash" "${username}"
        fi

        arch-chroot "${root_mount}" "passwd" "${username}" << chroot_commands
${password}
${password}
chroot_commands
    done
}

###################################################################################################
# installs the basic packages to make the system
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   configuration array
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::install()
{
    local root_mount="$1"
    local -n config=$2
    local host_name
    local root_partition

    # sync the repos and re-init the key ring
    system::init_installer_keyring

    # enable 32 bit applications on the install media
    system::enable_multilib ""

    # sync multilib repo
    system::sync_installer_repositories

    # format the selected drive, create file systems and swap
    disk::format "${config["drive"]}" "${config["uefi"]}" "${config["root_partition_size"]}" "${config["swap_partition_size"]}"

    # install the basic linux system
    system::install_base_linux "${root_mount}" "${config["kernel"]}" "${config["cpu_vendor"]}" "${config["install_micro_code"]}"

    # generate the file that keeps track of partitions
    system::generate_fstab "${root_mount}"

    system::set_locale "${root_mount}" "${config["locale"]}"

    system::set_key_map "${root_mount}" "${config["key_map"]}"

    host_name=$(echo "${config["computer_name"]}" | tr ' ' '-' | tr -dc '[:alnum:]-')

    system::set_hostname "${root_mount}" "${host_name}"

    system::generate_hosts "${root_mount}" "${host_name}"

    system::set_machine_info "${root_mount}" "${config["computer_name"]}" "${config["location"]}"

    system::generate_sudoers "${root_mount}"

    system::set_root_password "${root_mount}" "${config["root_password"]}"

    system::create_users "${root_mount}" "${config["users"]}"

    # enable 32 bit reop on new install
    system::enable_multilib "${root_mount}"

    if "${config["install_unofficial_repositories"]}"; then
        system::install_unofficial_repositories "${root_mount}"
    fi

    system::sync_repositories "${root_mount}"

    root_partition=$(disk::get_root_partition "${config["drive"]}")

    system::install_boot_loader "${config["uefi"]}" "${root_mount}" "${config["kernel"]}" "${root_partition}" "${config["cpu_vendor"]}" "${config["install_micro_code"]}"

    driver::install_gpu_driver "${root_mount}" "${config["gpu_driver"]}" "${config["uefi"]}" "${config["cpu_vendor"]}"

    system::enable_services "${root_mount}" "${config["enable_ssh_server"]}"
}
