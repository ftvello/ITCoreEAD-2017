#!/bin/bash

    # The MIT License (MIT)
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    # 
    # The above copyright notice and this permission notice shall be included in all
    # copies or substantial portions of the Software.
    # 
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    # SOFTWARE.

    #parameters 
{
    moodleVersion=$1
    glusterNode=$2
    glusterVolume=$3 
    moodledbapwd=$4
    siteFQDN=$5
    # create gluster mount point


    mkdir -p /moodle

    #configure gluster repository & install gluster client
    sudo add-apt-repository ppa:gluster/glusterfs-3.7 -y
    sudo apt-get -y update
    sudo apt-get -y --force-yes install glusterfs-client mysql-client git 

    # mount gluster files system
    echo -e '\n\rInstalling GlusterFS on '$glusterNode':/'$glusterVolume '/moodle\n\r' 
    sudo mount -t glusterfs $glusterNode:/$glusterVolume /moodle

    #create html directory for storing moodle files
    sudo mkdir -p /moodle/html

    # create directory for apache ssl certs
    sudo mkdir -p /moodle/certs

    # create moodledata directory
    sudo mkdir -p /moodle/moodledata

    # install pre-requisites
    sudo apt-get install -y --fix-missing python-software-properties unzip lsb-release bc

    REL=`lsb_release -sc`
    DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`
    NCORES=` cat /proc/cpuinfo | grep cores | wc -l`
    WORKER=`bc -l <<< "4*$NCORES"`

    wget http://nginx.org/keys/nginx_signing.key
    echo "deb http://nginx.org/packages/$DISTRO/ $REL nginx" >> /etc/apt/sources.list
    echo "deb-src http://nginx.org/packages/$DISTRO/ $REL nginx" >> /etc/apt/sources.list

    sudo apt-key add nginx_signing.key
    sudo apt-get update
    sudo apt-get install -fy nginx
    sudo apt-get install -fy php7.0-fpm php7.0-cli php7.0-mysql
    sudo apt-get install -fy php-apcu php7.0-gd

    # replace www-data to nginx into /etc/php5/fpm/pool.d/www.conf
    sed -i 's/www-data/nginx/g' /etc/php/7.0/fpm/pool.d/www.conf
    service php7.0-fpm restart

    # backup default Nginx configuration
    mkdir /etc/nginx/conf-bkp
    cp /etc/nginx/conf.d/default.conf /etc/nginx/conf-bkp/default.conf
    cp /etc/nginx/nginx.conf /etc/nginx/nginx-conf.old

    #
    # Replace nginx.conf
    #
    echo -e "user nginx www-data;\nworker_processes $WORKER;" > /etc/nginx/nginx.conf
    echo -e 'pid /var/run/nginx.pid;
    events {
        worker_connections 768;
        # multi_accept on;
    }
    http {
    # Basic Settings
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 5;
        types_hash_max_size 2048;
        # server_tokens off;
        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

    # Logging Settings
        log_format gzip '$remote_addr - $remote_user [$time_local]  '
            '"$request" $status $bytes_sent '
            '"$http_referer" "$http_user_agent" "$gzip_ratio"';
        access_log /var/log/nginx/access.log gzip buffer=32k;
        error_log /var/log/nginx/error.log notice;
    # Gzip Settings
        gzip on;
        gzip_disable "msie6";
        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    # Virtual Host Configs
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
    }' >> /etc/nginx/nginx.conf

    # replace Nginx default.conf
    #

    echo -e '# Upstream to abstract backend connection(s) for php
    upstream php {
    server unix:/var/run/php/php7.0-fpm.sock;
    #        server unix:/tmp/php-cgi.socket;
    #        server 127.0.0.1:9000;
    }
 
    server {
        listen       80;
        listen 443 ssl;
        
        #charset koi8-r;
        #access_log  /var/log/nginx/log/host.access.log  main;
        
        ## Your website name goes here.
        server_name localhost;
        
        ## Your only path reference.
        root /moodle/html/moodle;
        ssl_certificate /moodle/certs/nginx.crt;
        ssl_certificate_key /moodle/certs/nginx.key;

        ## This should be in your http block and if it is, it`s not needed here.
        index index.htm index.html index.php;
        gzip on;
        gzip_types text/css text/x-component application/x-javascript application/javascript text/javascript text/x-js text/richtext image/svg+xml text/plain text/xsd text/xsl text/xml image/x-icon;
        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }
 
        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }
 
        location / {
                # This is cool because no php is touched for static content. 
                # include the "?$args" part so non-default permalinks doesn`t break when using query string
                try_files $uri $uri/ /index.php?$args;
        }
        location ~ \.php$ {
            #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
            
            # root           html;
            # fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
            include        fastcgi_params;
            
            # include fastcgi.conf;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_intercept_errors on;
            fastcgi_pass php;
        }
        location ~ \.(ttf|ttc|otf|eot|woff|font.css)$ {
        add_header Access-Control-Allow-Origin "*";
        }
        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
        }
    }' > /etc/nginx/conf.d/default.conf

    echo -e "Generating SSL self-signed certificate"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /moodle/certs/nginx.key -out /moodle/certs/nginx.crt -subj "/C=BR/ST=SP/L=SaoPaulo/O=IT/CN=$siteFQDN"

    service php7.0-fpm restart
    service nginx restart

    sudo apt-get install -y --fix-missing php-cli php-common php-memcached php-pear php-xml php7.0-cgi php7.0-common php7.0-curl php7.0-dev php7.0-gd php7.0-intl \
    php7.0-json php7.0-ldap php7.0-mbstring php7.0-opcache php7.0-pspell php7.0-readline php7.0-soap php7.0-xml php7.0-xmlrpc php7.0-zip 

    # install Moodle 
    echo '#!/bin/bash
    cd /tmp
    # downloading moodle 
    curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/'$moodleVersion'.zip -L -o moodle.zip
    unzip moodle.zip
    echo -e \n\rMoving moodle files to Gluster\n\r 
    mv -v moodle-'$moodleVersion' /moodle/html/moodle
    # install Office 365 plugins
    #if [ "$installOfficePlugins" = "True" ]; then
            curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/'$moodleVersion'.zip -L -o o365.zip
            unzip o365.zip
            cp -r o365-moodle-'$moodleVersion'/* /moodle/html/moodle
            rm -rf o365-moodle-'$moodleVersion'
    #fi
    ' > /tmp/setup-moodle.sh 
    sudo chmod +x /tmp/setup-moodle.sh
    sudo /tmp/setup-moodle.sh

    # Install Plugin Kaltura
    sudo mkdir KALTURA ; cd KALTURA

    wget --no-check-certificate https://moodle.org/plugins/download.php/12933/Kaltura_Video_Package_moodle32_2016122232.zip

    unzip Kaltura_Video_Package_moodle32_2016122232.zip

    rm Kaltura_Video_Package_moodle32_2016122232.zip

    DESTDIR=/usr/share/nginx/html/moodle

    cp -Rap filter/kaltura/ $DESTDIR/filter/ && cp -Rap lib/editor/atto/plugins/kalturamedia $DESTDIR/lib/editor/atto/plugins/ \ 
    && cp -Rap lib/editor/tinymce/plugins/kalturamedia $DESTDIR/lib/editor/tinymce/plugins && cp -Rap local/* $DESTDIR/local/ && cp -Rap mod/* $DESTDIR/mod/

    cd .. && rm -rf KALTURA

    # create cron entry
    # It is scheduled for once per day. It can be changed as needed.
    echo '0 0 * * * php /moodle/html/moodle/admin/cli/cron.php > /dev/null 2>&1' > cronjob
    sudo crontab cronjob

    # php config 
    PhpIni=/etc/php/7.0/fpm/php.ini
    sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
    echo "extension=/usr/lib/php/20151012/apcu.so" >> $PhpIni
    sudo chown -R nginx /moodle/html/moodle
    sudo chown -R nginx /moodle/certs
    sudo chown -R nginx /moodle/moodledata
    sudo chmod -R 770 /moodle/html/moodle
    sudo chmod -R 770 /moodle/certs
    sudo chmod -R 770 /moodle/moodledata
     # restart Apache
    echo -e "\n\rRestarting Nginx server\n\r"
    service php7.0-fpm restart
    service nginx restart
    
    echo -e "sudo -u nginx /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=pt_br --wwwroot=https://"$siteFQDN" --dataroot=/moodle/moodledata --dbhost=172.18.2.5 --dbpass="$moodledbapwd" --dbtype=mariadb --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass="$moodledbapwd" --adminemail=admin@"$siteFQDN" --non-interactive --agree-license --allow-unstable || true "
    sudo -u nginx /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=pt_br --wwwroot=https://$siteFQDN --dataroot=/moodle/moodledata --dbhost=172.18.2.5 --dbpass=$moodledbapwd --dbtype=mariadb --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$moodledbapwd --adminemail=admin@$siteFQDN --non-interactive --agree-license --allow-unstable || true

    #Tunning

    pecl install channel://pecl.php.net/apcu-5.1.8

    echo -e 'apc.enabled=1
    apc.shm_segments=1
    ;32M per WordPress install
    apc.shm_size=128M
    ;Relative to the number of cached files (you may need to watch your stats for a day or two to find out a good number)
    apc.num_files_hint=7000
    ;Relative to the size of WordPress
    apc.user_entries_hint=4096
    ;The number of seconds a cache entry is allowed to idle in a slot before APC dumps the cache
    apc.ttl=7200
    apc.user_ttl=7200
    apc.gc_ttl=3600
    ;Setting this to 0 will give you the best performance, as APC will
    ;not have to check the IO for changes. However, you must clear
    ;the APC cache to recompile already cached files. If you are still
    ;developing, updating your site daily in WP-ADMIN, and running W3TC
    ;set this to 1
    apc.stat=1
    ;This MUST be 0, WP can have errors otherwise!
    apc.include_once_override=0
    ;Only set to 1 while debugging
    apc.enable_cli=0
    ;Allow 2 seconds after a file is created before it is cached to prevent users from seeing half-written/weird pages
    apc.file_update_protection=2
    ;Leave at 2M or lower. WordPress doest have any file sizes close to 2M
    apc.max_file_size=2M
    apc.cache_by_default=1
    apc.use_request_time=1
    apc.slam_defense=0
    ;apc.mmap_file_mask=/tmp/apc.tmp
    apc.stat_ctime=0
    apc.canonicalize=1
    apc.write_lock=1
    apc.report_autofilter=0
    apc.rfc1867=0
    apc.rfc1867_prefix =upload_
    apc.rfc1867_name=APC_UPLOAD_PROGRESS
    apc.rfc1867_freq=0
    apc.rfc1867_ttl=3600
    apc.lazy_classes=0
    apc.lazy_functions=0' > /etc/php/7.0/mods-available/apcu.ini

    echo -e "[www]
    user = www-data
    group = www-data
    listen = 127.0.0.1:9000
    listen.backlog = -1
    listen.owner = www-data
    listen.group = www-data
    listen.allowed_clients = 127.0.0.1
    pm = dynamic
    pm.max_children = 25
    pm.start_servers = 2
    pm.min_spare_servers = 1
    pm.max_spare_servers = 3
    pm.max_requests = 5000
    slowlog = /var/log/php7.0-fpm.slow
    request_slowlog_timeout = 20s
    rlimit_files = 50000
    rlimit_core = unlimited
    chdir = /
    catch_workers_output = yes
    env[HOSTNAME] = 'webazumooclavm000001'
    env[NLS_LANG] = 'BRAZILIAN PORTUGUESE_BRAZIL.AL32UTF8'
    env[NLS_TERRITORY] = 'BRAZIL'
    env[NLS_DUAL_CURRENCY] = 'R\$'
    env[NLS_CURRENCY] = 'R\$'
    env[NLS_ISO_CURRENCY] = 'BRAZIL'
    env[NLS_DATE_LANGUAGE] = 'BRAZILIAN PORTUGUESE'
    env[NLS_DATE_FORMAT] = 'DD/MM/YYYY'
    env[NLS_TIME_FORMAT] = 'HH24:MI:SS'
    env[NLS_TIMESTAMP_FORMAT] = 'DD/MM/YYYY HH24:MI:SS'
    php_admin_value[error_log] = /var/log/fpm-php.www.log
    php_admin_flag[log_errors] = on
    php_value[session.save_handler] = files
    php_value[session.save_path]    = /var/lib/php/session
    php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache" > /etc/php/7.0/fpm/pool.d/www.conf
    
    echo -e "\n\rDone! Installation completed!\n\r"

    } > /tmp/install.log
