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
    while [[ -z ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif ! [[ -z ${typed} ]]; then
            value=${typed}
        fi
    done
    echo ${value}
}

# installation functions
function install_packages()
{
    pacman -S nextcloud mariadb php-fpm php-intl php-imagick php-gd << EOF
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
EOF
}

function configure_mariadb()
{
    # set local parameters
    local data_folder=${1}
    local root_password=${2}
    local nextcloud_password=${3}

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
    mysql -u root << EOF
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '${nextcloud_password}';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES on nextcloud.* to 'nextcloud'@'localhost';
FLUSH privileges;
exit
EOF
}

function configure_ini()
{
    # define local parameters
    local ini_file=${1}
    local memory_limit=${2}
    local timezone=${3}

    local upload_max_filesize=${4}
    local post_max_size=${5}

    local max_input_time=${6}
    local max_execution_time=${7}

    # configure settings
    sed -i "s/memory_limit =.*/memory_limit = ${memory_limit}/" ${ini_file}
    sed -i "s,;date.timezone =,date.timezone = ${timezone}," ${ini_file}

    sed -i "s/upload_max_filesize =.*/upload_max_filesize = ${upload_max_filesize}/" ${ini_file}
    sed -i "s/post_max_size =.*/post_max_size = ${post_max_size}/" ${ini_file}

    sed -i "s/max_input_time =.*/max_input_time = ${max_input_time}/" ${ini_file}
    sed -i "s/max_execution_time =.*/max_execution_time = ${max_execution_time}/" ${ini_file}

    # configure extensions
    sed -i "s/;extension=bcmath/extension=bcmath/" ${ini_file}
    sed -i "s/;extension=bz2/extension=bz2/" ${ini_file}
    sed -i "s/;extension=exif/extension=exif/" ${ini_file}
    sed -i "s/;extension=gd/extension=gd/" ${ini_file}
    sed -i "s/;extension=gmp/extension=gmp/" ${ini_file}
    sed -i "s/;extension=intl/extension=intl/" ${ini_file}
    sed -i "s/;extension=iconv/extension=iconv/" ${ini_file}
    sed -i "s/;extension=pdo_mysql/extension=pdo_mysql/" ${ini_file}
    sed -i "s/;extension=mysqli/extension=mysqli/" ${ini_file}
    sed -i "/^;extension=gzip.*/a extension=imagick" ${ini_file}

}

function configure_php()
{
    # define local parameters
    local nextcloud_data_folder=${1}

    local memory_limit=${2}
    local timezone=${3}

    local upload_max_filesize=${4}
    local post_max_size=${5}

    local max_input_time=${6}
    local max_execution_time=${7}

    # define the php.ini file paths
    local php_ini="/etc/php/php.ini"
    local nextcloud_ini="/etc/webapps/nextcloud/php.ini"
    local fpm_ini="/etc/php/php-fpm.ini"

    # create php ini files for nextcloud and php-fpm
    cp ${php_ini} ${nextcloud_ini}
    chown "nextcloud:nextcloud" ${nextcloud_ini}
    cp ${php_ini} ${fpm_ini}
    chown "root:root" ${fpm_ini}

    # configure basic settings
    configure_ini "${nextcloud_ini}" "${memory_limit}" "${timezone}" "${upload_max_filesize}" "${post_max_size}" "${max_input_time}" "${max_execution_time}"
    configure_ini "${fpm_ini}" "${memory_limit}" "${timezone}" "${upload_max_filesize}" "${post_max_size}" "${max_input_time}" "${max_execution_time}"

    # configure php-fpm.ini only
    sed -i "s/;zend_extension=.*/zend_extension=opcache/" ${fpm_ini}
    sed -i "s/;opcache.enable=.*/;opcache.enable = 1/" ${fpm_ini}
    sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer = 8/" ${fpm_ini}
    sed -i "s/;opcache.max_accelerated_files=.*/;opcache.max_accelerated_files = 10000/" ${fpm_ini}
    sed -i "s/;opcache.memory_consumption=.*/;opcache.memory_consumption = 128/" ${fpm_ini}
    sed -i "s/;opcache.save_comments=.*/opcache.save_comments = 1/" ${fpm_ini}
    sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq = 1/" ${fpm_ini}

    # configure service
    local service_folder="/etc/systemd/system/php-fpm.service.d/"
    mkdir -p ${service_folder}
    local service_file="${service_folder}override.conf"
    echo "
    [Service]
    ExecStart=
    ExecStart=/usr/bin/php-fpm --nodaemonize --fpm-config /etc/php/php-fpm.conf --php-ini /etc/php/php-fpm.ini
    ReadWritePaths=${nextcloud_data_folder}
    ReadWritePaths=/etc/webapps/nextcloud/config
    " > "${service_file}"

    # define config files
    local conf_folder="/etc/php/php-fpm.d/"
    local www_conf_file="${conf_folder}www.conf"
    local nextcloud_conf_file="${conf_folder}nextcloud.conf"
    local backup_conf_file="${conf_folder}www.conf.backup"

    cp ${www_conf_file} ${nextcloud_conf_file}
    cp ${www_conf_file} ${backup_conf_file}

    # clear existing www.conf
    echo ";" > ${www_conf_file}

    # add configuration to pool settings, should match the settings in /etc/webapps/nextcloud/php.ini but does not need to match /etc/php/php-fpm.ini
    sed -i "s/user = http/user = nextcloud/" ${nextcloud_conf_file}
    sed -i "s/group = http/group = nextcloud/" ${nextcloud_conf_file}

    echo "
php_value[memory_limit] = ${memory_limit}
php_value[date.timezone] = ${timezone}
php_value[upload_max_filesize] = ${upload_max_filesize}
php_value[post_max_size] = ${post_max_size}
php_value[max_input_time] = ${max_input_time}
php_value[max_execution_time] = ${max_execution_time}

php_value[extension] = bcmath
php_value[extension] = bz2
php_value[extension] = exif
php_value[extension] = gd
php_value[extension] = gmp
php_value[extension] = intl
php_value[extension] = iconv
php_value[extension] = pdo_mysql
php_value[extension] = mysqli
php_value[extension] = imagick
" >> ${nextcloud_conf_file}

    # set up pacman hook to update the database
    mkdir -vp "/etc/pacman.d/hooks"
    cp -a "/usr/share/doc/nextcloud/nextcloud.hook" "/etc/pacman.d/hooks/nextcloud.hook"

    sed -i "s,Exec =.*,Exec = /usr/bin/runuser -u nextcloud -- /usr/bin/php --php-ini /etc/webapps/nextcloud/php.ini /usr/share/webapps/nextcloud/occ upgrade," "/etc/pacman.d/hooks/nextcloud.hook"

    # set owner and group
    chown "nextcloud:nextcloud" "/etc/webapps/nextcloud" -R
    chown "nextcloud:nextcloud" "/usr/share/webapps/nextcloud" -R
    chown "nextcloud:nextcloud" ${nextcloud_data_folder} -R
    chown "nextcloud:nextcloud" "/var/lib/nextcloud/" -R

    # set permissions
    chmod "755" "/etc/webapps/nextcloud" -R
    chmod "755" "/usr/share/webapps/nextcloud" -R
    chmod "755" ${nextcloud_data_folder} -R
    chmod "755" "/var/lib/nextcloud/" -R
}

install_packages

mysql_data_folder=$(read_folder "${mysql_data_folder_prompt}" "${mysql_data_folder}")
echo $mysql_data_folder

root_database_password=$(read_password "${root_database_password_prompt}")
echo $root_database_password

nextcloud_database_password=$(read_password "${nextcloud_database_password_prompt}")
echo $nextcloud_database_password

configure_mariadb "${mysql_data_folder}" "${root_database_password}" "${nextcloud_database_password}"

configure_php "${nextcloud_data_folder}" "${memory_limit}" "${timezone}" "${upload_max_filesize}" "${post_max_size}" "${max_input_time}" "${max_execution_time}"
