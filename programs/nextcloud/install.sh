#!/usr/bin/bash

# this script assumes a fresh install of arch linux
# errors may appear if some configuration files already exist for the packages being installed

# define variables
# data folders
mysql_data_folder='/var/lib/mysql/'
nextcloud_data_folder='/var/lib/nextcloud/data/'
nextcloud_folder='/var/lib/nextcloud/'

mysql_data_folder_prompt='Enter folder path where MySQL data should be stored'
nextcloud_data_folder_prompt='Enter folder path where NextCloud data should be stored'

# php.ini settings
memory_limit='1G'
timezone='America/Chicago'

upload_max_filesize='16G'
post_max_size='4G'

max_input_time='3600'
max_execution_time='3600'
max_file_uploads='500'

memory_limit_prompt='Enter NextCloud memory limit'
timezone_prompt='Enter NextCloud timezone'

upload_max_filesize_prompt='Enter NextCloud maximum file size for uploading'
post_max_size_prompt='Enter NextCloud maximum "POST" file size'

max_input_time_prompt='Enter NextCloud maximum input time in seconds'
max_execution_time_prompt='Enter NextCloud maximum execution time in seconds'
max_file_uploads_prompt='Enter NextCloud maximum file upload count'

# mysql database
root_database_password=''
nextcloud_database_password=''

root_database_password_prompt='Enter root user password for the mysql database'
nextcloud_database_password_prompt='Enter NextCloud user password for the mysql database'

# nextcloud admin account information
admin_email='admin@example.com'
admin_password='admin'

admin_email_prompt='Enter NextCloud admin email'
admin_password_prompt='Enter NextCloud admin password'

# nextcloud config
nextcloud_domain='cloud.example.com'
nextcloud_url='http://cloud.example.com'
nextcloud_port='80'

nextcloud_url_prompt='Enter the url which will be used to access NextCloud'

# input functions
function read_storage_size()
{
    local prompt="${1}: "
    local default_value=${2}
    local typed=''
    local value=''
    local regex='^[0-9]+[bkmgBKMG]$'
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}(default: ${default_value})"
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
    local prompt="${1}: "
    local default_value=${2}
    local typed=''
    local value=''
    local regex='^[0-9]+$'
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}(default: ${default_value})"
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
    local prompt="${1}: "
    local default_value=${2}
    local typed=''
    local value=''
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}(default: ${default_value})"
    fi
    while ! [[ -d ${value} ]]; do
        read -p "${prompt}" typed
        if [[ -z ${typed} ]] && ! [[ -z ${default_value} ]]; then
            value=${default_value}
        elif [[ -d ${typed} ]]; then
            value=${typed}
            if ! [[ ${value} = */ ]]; then
                value="${value}/"
            fi
        fi
    done
    echo ${value}
}

function read_email()
{
    local prompt="${1}: "
    local default_value=${2}
    local typed=''
    local value=''
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$'
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}(default: ${default_value})"
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

function read_password()
{
    local prompt="${1}: "
    local default_value=${2}
    local typed=''
    local value=''
    if ! [[ -z ${default_value} ]]; then
        prompt="${prompt}(default: ${default_value})"
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
    pacman -S nextcloud nginx mariadb php-fpm php-intl php-imagick php-gd << EOF
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
    # init mariadb
    mariadb-install-db --user=mysql --basedir=/usr --datadir=${mysql_data_folder}

    # set data directory in the server.cnf
    sed -i "/\[server\]/a datadir=${mysql_data_folder}" "/etc/my.cnf.d/server.cnf"

    # enable and start database
    systemctl enable mariadb --now

    # cleanup and "secure" mariadb
    mysql_secure_installation << EOF
$(echo)
y
y
${root_database_password}
${root_database_password}
y
y
y
y
EOF

    # add nextcloud user to database
    mysql -u root << EOF
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '${nextcloud_database_password}';
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

    # configure settings
    sed -i "s/memory_limit =.*/memory_limit = ${memory_limit}/" ${ini_file}
    sed -i "s,;date.timezone =,date.timezone = ${timezone}," ${ini_file}

    sed -i "s/upload_max_filesize =.*/upload_max_filesize = ${upload_max_filesize}/" ${ini_file}
    sed -i "s/post_max_size =.*/post_max_size = ${post_max_size}/" ${ini_file}

    sed -i "s/max_input_time =.*/max_input_time = ${max_input_time}/" ${ini_file}
    sed -i "s/max_execution_time =.*/max_execution_time = ${max_execution_time}/" ${ini_file}

    sed -i "s/max_file_uploads =.*/max_file_uploads = ${max_file_uploads}/" ${ini_file}

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
    sed -i "/^extension=zip.*/a extension=imagick" ${ini_file}

}

function configure_php()
{
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
    configure_ini "${nextcloud_ini}"
    configure_ini "${fpm_ini}"

    # configure php-fpm.ini only
    sed -i "s/;zend_extension=.*/zend_extension=opcache/" ${fpm_ini}
    sed -i "s/;opcache.enable=.*/opcache.enable = 1/" ${fpm_ini}
    sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer = 8/" ${fpm_ini}
    sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files = 10000/" ${fpm_ini}
    sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption = 128/" ${fpm_ini}
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
ReadWritePaths=${nextcloud_folder}
ReadWritePaths=/etc/webapps/nextcloud/config
" > "${service_file}"

    # define config files
    local conf_folder="/etc/php/php-fpm.d/"
    local www_conf_file="${conf_folder}www.conf"
    local nextcloud_conf_file="${conf_folder}nextcloud.conf"
    local backup_conf_file="${conf_folder}www.conf.package"

    cp ${www_conf_file} ${nextcloud_conf_file}
    cp ${www_conf_file} ${backup_conf_file}

    # clear existing www.conf
    echo ";" > ${www_conf_file}

    # add configuration to pool settings, should match the settings in /etc/webapps/nextcloud/php.ini but does not need to match /etc/php/php-fpm.ini
    sed -i "s/user = http/user = nextcloud/" ${nextcloud_conf_file}
    sed -i "s/group = http/group = nextcloud/" ${nextcloud_conf_file}

    sed -i "s/;env\[HOSTNAME\] =.*/env[HOSTNAME] = \$HOSTNAME/" ${nextcloud_conf_file}
    sed -i "s,;env\[PATH\] =.*,env[PATH] = /usr/local/bin:/user/bin:/bin," ${nextcloud_conf_file}
    sed -i "s,;env\[TMP\] =.*,env[TMP] = /tmp," ${nextcloud_conf_file}
    sed -i "s,;env\[TMPDIR\] =.*,env[TMP] = /tmp," ${nextcloud_conf_file}
    sed -i "s,;env\[TEMP\] =.*,env[TMP] = /tmp," ${nextcloud_conf_file}

    echo "
php_value[memory_limit] = ${memory_limit}
php_value[date.timezone] = ${timezone}
php_value[upload_max_filesize] = ${upload_max_filesize}
php_value[post_max_size] = ${post_max_size}
php_value[max_input_time] = ${max_input_time}
php_value[max_execution_time] = ${max_execution_time}
php_value[max_file_uploads] = ${max_file_uploads}

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
    chown "nextcloud:nextcloud" ${nextcloud_folder} -R
    chown "nextcloud:nextcloud" "/var/lib/nextcloud/" -R

    # set permissions
    chmod "755" "/etc/webapps/nextcloud" -R
    chmod "755" "/usr/share/webapps/nextcloud" -R
    chmod "755" ${nextcloud_data_folder} -R
    chmod "755" ${nextcloud_folder} -R
    chmod "755" "/var/lib/nextcloud/" -R

    systemctl enable php-fpm.service --now
}

function configure_nextcloud()
{
    # install the database tables and add the admin user
    export NEXTCLOUD_PHP_CONFIG=/etc/webapps/nextcloud/php.ini

    occ maintenance:install \
        --database=mysql \
        --database-name=nextcloud \
        --database-host=localhost:/run/mysqld/mysqld.sock \
        --database-user=nextcloud \
        --database-pass=${nextcloud_database_password} \
        --admin-pass=${admin_password} \
        --admin-email=${admin_email} \
        --data-dir=${nextcloud_data_folder}

    # install sessions folder
    install --owner=nextcloud --group=nextcloud --mode=700 -d "${nextcloud_folder}sessions"

    # add domain to the list of trusted domains
    sed -i "/0 => 'localhost',/a 1 => '${nextcloud_domain}'" "/etc/webapps/nextcloud/config/config.php"

    # update cli url rewrite
    sed -i "s,http://localhost,${nextcloud_url}," "/etc/webapps/nextcloud/config/config.php"
}

function configure_nginx()
{
    local nginx_config_file="/etc/nginx/nginx.conf"
    local nextcloud_nginx_config_file="/etc/nginx/conf.d/nextcloud.conf"
    mkdir "/etc/nginx/conf.d/"

    # add the configuration file for nginx
    # \ . $ have been escaped where required
    # Ermanno Ferrari's configuration, can be found here:
    # https://gitlab.com/eflinux/nextcloudarch
    cat > ${nextcloud_nginx_config_file} << EOF
server {
    listen ${nextcloud_port};
    server_name ${nextcloud_domain};

    # Add headers to serve security related headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Download-Options noopen;
    add_header X-Permitted-Cross-Domain-Policies none;

    # Path to the root of your installation
    root /usr/share/webapps/nextcloud/;

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # The following 2 rules are only needed for the user_webfinger app.
    # Uncomment it if you're planning to use this app.
    #rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
    #rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json
    # last;

    location = /.well-known/carddav {
        return 301 \$scheme://\$host/remote.php/dav;
    }
    location = /.well-known/caldav {
       return 301 \$scheme://\$host/remote.php/dav;
    }

    location ~ /.well-known/acme-challenge {
      allow all;
    }

    # set max upload size
    client_max_body_size 512M;
    fastcgi_buffers 64 4K;

    # Disable gzip to avoid the removal of the ETag header
    gzip off;

    # Uncomment if your server is build with the ngx_pagespeed module
    # This module is currently not supported.
    #pagespeed off;

    error_page 403 /core/templates/403.php;
    error_page 404 /core/templates/404.php;

    location / {
       rewrite ^ /index.php\$uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
       deny all;
    }
    location ~ ^/(?:\\.|autotest|occ|issue|indie|db_|console) {
       deny all;
     }

    location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {
       include fastcgi_params;
       fastcgi_split_path_info ^(.+\\.php)(/.*)$;
       fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
       fastcgi_param PATH_INFO \$fastcgi_path_info;
       #Avoid sending the security headers twice
       fastcgi_param modHeadersAvailable true;
       fastcgi_param front_controller_active true;
       fastcgi_pass unix:/run/php-fpm/php-fpm.sock;
       fastcgi_intercept_errors on;
       fastcgi_request_buffering off;
    }

    location ~ ^/(?:updater|ocs-provider)(?:$|/) {
       try_files \$uri/ =404;
       index index.php;
    }

    # Adding the cache control header for js and css files
    # Make sure it is BELOW the PHP block
    location ~* \\.(?:css|js)$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        add_header Cache-Control "public, max-age=7200";
        # Add headers to serve security related headers (It is intended to
        # have those duplicated to the ones above)
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Robots-Tag none;
        add_header X-Download-Options noopen;
        add_header X-Permitted-Cross-Domain-Policies none;
        # Optional: Don't log access to assets
        access_log off;
   }

   location ~* \\.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        # Optional: Don't log access to other assets
        access_log off;
   }
}
EOF
    chmod "755" ${nextcloud_nginx_config_file}

    # configure existing nginx conf to include other configs
    sed -i "/mime.types;/a include /etc/nginx/conf.d/*.conf;" ${nginx_config_file}

    # configure the fastcgi pass through, builds from the bottom up
    sed -i "/# pass the PHP.*/a }" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a include fastcgi_params;" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a fastcgi_index index.php;" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a fastcgi_pass unix:/run/php-fpm/php-fpm.sock;" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a root /usr/share/nginx/html;" ${nginx_config_file}
    sed -i "/# pass the PHP.*/a location ~ \\.php\$ {" ${nginx_config_file}

    systemctl enable nginx.service --now
}

install_packages

# read in user settings
clear
mysql_data_folder=$(read_folder "${mysql_data_folder_prompt}" "${mysql_data_folder}")
echo $mysql_data_folder

nextcloud_data_folder=$(read_folder "${nextcloud_data_folder_prompt}" "${nextcloud_data_folder}")
echo $nextcloud_data_folder

root_database_password=$(read_password "${root_database_password_prompt}")
echo $root_database_password

nextcloud_database_password=$(read_password "${nextcloud_database_password_prompt}")
echo $nextcloud_database_password

nextcloud_url=$(read_password "${nextcloud_url_prompt}" "${nextcloud_url}")
echo $nextcloud_url

domain_and_port=$(echo ${nextcloud_url} | awk -F/ '{print $3}')

nextcloud_domain=$(echo "${domain_and_port}" | sed 's/:.*//')
echo $nextcloud_domain

nextcloud_port=$(echo "${domain_and_port}" | awk -F: '{print $2}')
if [[ -z ${nextcloud_port} ]]; then
    https_regex='^https.*'
    if [[ ${nextcloud_url} =~ ${https_regex} ]]; then
        nextcloud_port='443'
    else
        nextcloud_port='80'
    fi
fi
echo $nextcloud_port

timezone=$(read_password "${timezone_prompt}" "${timezone}")
echo $timezone

memory_limit=$(read_storage_size "${memory_limit_prompt}" "${memory_limit}")
echo $memory_limit

upload_max_filesize=$(read_storage_size "${upload_max_filesize_prompt}" "${upload_max_filesize}")
echo $upload_max_filesize

post_max_size=$(read_storage_size "${post_max_size_prompt}" "${post_max_size}")
echo $post_max_size

admin_email=$(read_email "${admin_email_prompt}" "${admin_email}")
echo $admin_email

admin_password=$(read_password "${admin_password_prompt}")
echo $admin_password

max_input_time=$(read_whole_number "${max_input_time_prompt}" "${max_input_time}")
echo $max_input_time

max_execution_time=$(read_whole_number "${max_execution_time_prompt}" "${max_execution_time}")
echo $max_execution_time

max_file_uploads=$(read_whole_number "${max_file_uploads_prompt}" "${max_file_uploads}")
echo $max_file_uploads

# configure install
configure_mariadb
configure_php
configure_nextcloud
configure_nginx

clear
echo "Basic NextCloud installation is now complete."
echo "Setup a dns rewrite from your dns server to point ${nextcloud_domain} to this server's ip address."
