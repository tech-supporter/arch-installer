#!/usr/bin/bash

# define variables

# data folders
mysql_data_folder='/var/lib/mysql'
nextcloud_data_folder='/var/lib/nextcloud'

mysql_data_folder_prompt='Enter folder path where MySQL data should be stored'
nextcloud_data_folder_prompt='Enter folder path where NextCloud data should be stored'

# php.ini settings
memory_limit='1G'
timezone='America/Chicago'

upload_max_filesize='16G'
post_max_size='16G'

max_input_time='3600'
max_execution_time='3600'

memory_limit_prompt='Enter NextCloud memory limit'
timezone_prompt='Enter NextCloud timezone'

upload_max_filesize_prompt='Enter NextCloud maximum file size for uploading'
post_max_size_prompt='Enter NextCloud maximum "POST" file size'

max_input_time_prompt='Enter NextCLoud maximum input time in seconds'
max_execution_time_prompt='Enter NextCLoud maximum execution time in seconds'

# mysql database
root_database_password=''
nextcloud_database_password=''

root_database_password_prompt='Enter root user password for the mysql database'
nextcloud_database_password_prompt='Enter NextCloud user password for the mysql database'

# nextcloud admin account information
admin_email=''
admin_password=''

admin_email_prompt='Enter NextCloud admin email'
admin_password_prompt='Enter NextCLoud admin password'

# nextcloud config
nextcloud_dmoain=''
nextcloud_url=''
nextcloud_port='80'

nextcloud_domain_prompt='Enter the domain which will be used to access NextCloud'
nextcloud_url_prompt='Enter the url which will be used to access NextCloud'
nextcloud_port_prompt='Enter the port which will be used to access NextCloud [443 for https, 80 for http]'

# input functions
function read_storage_size()
{
    local prompt=${1}
    local default_value=${2}
    local typed=''
    local value=''
    local regex='^[0-9]+[bkmgBKMG]$'
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}: (default: ${default_value})"
    fi
    while [[ -z ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif [[ ${typed} =~ ${regex} ]]; then
            value=$( echo ${typed} | tr '[:lower:]' '[:upper:]' )
        fi
    done
    echo ${value}
}

function read_whole_number()
{
    local prompt=${1}
    local default_value=${2}
    local typed=''
    local value=''
    local regex='^[0-9]+$'
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}: (default: ${default_value})"
    fi
    while [[ -z ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif [[ ${typed} =~ ${regex} ]]; then
            value=${typed}
        fi
    done
    echo ${value}
}

function read_folder()
{
    local prompt=${1}
    local default_value=${2}
    local typed=''
    local value=''
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}: (default: ${default_value})"
    fi
    while ! [[ -d ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif [[ -d ${typed} ]]; then
            value=${typed}
        fi
    done
    echo ${value}
}

function read_password()
{
    local prompt=${1}
    local default_value=${2}
    local typed=''
    local value=''
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}: (default: ${default_value})"
    fi
    while ! [[ -d ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif [[ -d ${typed} ]]; then
            value=${typed}
        fi
    done
    echo ${value}
}

# installation functions
function install_mariadb()
{
    # set local parameters
    local data_folder=${1}
    local root_password=${2}
    local nextcloud_password=${3}

    # install db package
    pacman -S mariadb << install_commands
y
install_commands

    # init mariadb
    mariadb-install-db --user=mysql --basedir=/usr --datadir=${data_folder}

    # enable and start database
    systemctl enable mariadb --now

    # cleanup and "secure" mariadb
    mysql_secure_installation << EOF
$(echo)
y
y
${root_password}
${root_password}
y
y
y
y
EOF

    # add nextcloud user to database
    mysql -u root -p
${root_password}
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '${nextcloud_password}';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES on nextcloud.* to 'nextcloud'@'localhost';
FLUSH privileges;
EOF
}

mysql_data_folder=$(read_folder "${mysql_data_folder_prompt}" "${mysql_data_folder}")
echo $mysql_data_folder

root_database_password=$(read_whole_number "${root_database_password_prompt}")
echo $root_database_password

nextcloud_database_password=$(read_whole_number "${nextcloud_database_password_prompt}")
echo $nextcloud_database_password

install_mariadb "${mysql_data_folder}" "${root_database_password}" "${nextcloud_data_folder}"
