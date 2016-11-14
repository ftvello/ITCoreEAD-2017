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

glusterNode=$1
glusterVolume=$2 

# install pre-requisites
sudo apt-get -y install python-software-properties

#configure gluster repository & install gluster client
sudo add-apt-repository ppa:gluster/glusterfs-3.7 -y
sudo apt-get -y update
sudo apt-get -y --force-yes install glusterfs-client mysql-client git 


# install the LAMP stack
sudo apt-get -y install apache2 php5

# install moodle requirements
sudo apt-get -y install graphviz aspell php5-pspell php5-curl php5-gd php5-intl php5-mysql php5-xmlrpc php5-ldap php5-redis

# install modules for tunning
sudo apt-get -y install libapache2-mod-fastcgi php5-fpm php5-apcu

# create gluster mount point
sudo mkdir -p /moodle

# make the moodle directory writable for owner
sudo chown www-data moodle
sudo chmod 770 moodle
 
# mount gluster files system
sudo echo -e 'mount -t glusterfs '$glusterNode':/'$glusterVolume' /moodle' > /tmp/mount.log 
#sudo mount -t glusterfs $glusterNode:/$glusterVolume /moodle
sudo echo -e $glusterNode':/'$glusterVolume'   /moodle         glusterfs       defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log 0 0' >> /etc/fstab
sudo mount -a
# updapte Apache configuration
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
sudo sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf
sudo echo ServerName \"localhost\"  >> /etc/apache2/apache2.conf

#enable ssl 
sudo a2enmod rewrite ssl

#update virtual site configuration 
echo -e '
<VirtualHost *:80>
        #ServerName www.example.com
        ServerAdmin webmaster@localhost
        DocumentRoot /moodle/html/moodle
        #LogLevel info ssl:warn
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>
<VirtualHost *:443>
        DocumentRoot /moodle/html/moodle
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        SSLEngine on
        SSLCertificateFile /moodle/certs/fullchain.pem
        SSLCertificateKeyFile /moodle/certs/privkey.pem
        #SSLCertificateFile /moodle/certs/da0c9b915e6265f2.crt
        #SSLCertificateKeyFile /moodle/certs/privateKey.pem
        BrowserMatch "MSIE [2-6]" \
                        nokeepalive ssl-unclean-shutdown \
                        downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>' > /etc/apache2/sites-enabled/000-default.conf

#Tunnig
sudo touch /usr/lib/cgi-bin/php5.fcgi
sudo chown -R www-data:www-data /usr/lib/cgi-bin

echo -e '<IfModule mod_fastcgi.c>
AddHandler php5-fcgi .php
Action php5-fcgi /php5-fcgi
Alias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi
FastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi -socket /var/run/php5-fpm.sock -pass-header Authorization
<Directory /usr/lib/cgi-bin>
    Require all granted
</Directory>
</IfModule>' > /etc/apache2/conf-available/php5-fpm.conf

echo -e '<IfModule mod_deflate.c>
        <IfModule mod_filter.c>
                # these are known to be safe with MSIE 6
                AddOutputFilterByType DEFLATE text/html text/plain text/xml
                # everything else may cause problems with MSIE 6
                AddOutputFilterByType DEFLATE text/css
                AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
                AddOutputFilterByType DEFLATE application/rss+xml
                AddOutputFilterByType DEFLATE application/xml
                AddOutputFilterByType DEFLATE application/xml
                AddOutputFilterByType DEFLATE application/xhtml+xml
                AddOutputFilterByType DEFLATE application/rss+xml
                AddOutputFilterByType DEFLATE application/javascript
                AddOutputFilterByType DEFLATE application/x-javascript
                AddOutputFilterByType DEFLATE text/plain
                AddOutputFilterByType DEFLATE text/html
                AddOutputFilterByType DEFLATE text/xml
                AddOutputFilterByType DEFLATE text/css
                AddOutputFilterByType DEFLATE image/x-icon
        </IfModule>
</IfModule>' > /etc/apache2/mods-enabled/deflate.conf

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
#apc.mmap_file_mask=/tmp/apc.tmp
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
apc.lazy_functions=0' > /etc/php5/mods-available/apcu.ini

echo -e '; Determines if Zend OPCache is enabled
opcache.enable=1
; Determines if Zend OPCache is enabled for the CLI version of PHP
opcache.enable_cli=1
; The OPcache shared memory storage size.
opcache.memory_consumption=128
; The amount of memory for interned strings in Mbytes.
opcache.interned_strings_buffer=8
; The maximum number of keys (scripts) in the OPcache hash table.
; Only numbers between 200 and 100000 are allowed.
opcache.max_accelerated_files=7000
; The maximum percentage of "wasted" memory until a restart is scheduled.
;opcache.max_wasted_percentage=5
; When this directive is enabled, the OPcache appends the current working
; directory to the script key, thus eliminating possible collisions between
; files with the same name (basename). Disabling the directive improves
; performance, but may break existing applications.
;opcache.use_cwd=1
; When disabled, you must reset the OPcache manually or restart the
; webserver for changes to the filesystem to take effect.
;opcache.validate_timestamps=1
; How often (in seconds) to check file timestamps for changes to the shared
; memory storage allocation. ("1" means validate once per second, but only
; once per request. "0" means always validate)
opcache.revalidate_freq=60
; Enables or disables file search in include_path optimization
;opcache.revalidate_path=0
; If disabled, all PHPDoc comments are dropped from the code to reduce the
 ;size of the optimized code.
;opcache.save_comments=1
; If disabled, PHPDoc comments are not loaded from SHM, so "Doc Comments"
; may be always stored (save_comments=1), but not loaded by applications
; that dont need them anyway.
;opcache.load_comments=1
; If enabled, a fast shutdown sequence is used for the accelerated code
opcache.fast_shutdown=1
; Allow file existence override (file_exists, etc.) performance feature.
;opcache.enable_file_override=0
; A bitmask, where each bit enables or disables the appropriate OPcache
; passes
;opcache.optimization_level=0xffffffff
;opcache.inherited_hack=1
;opcache.dups_fix=0
; The location of the OPcache blacklist file (wildcards allowed).
; Each OPcache blacklist file is a text file that holds the names of files
; that should not be accelerated.
opcache.blacklist_filename=/etc/php.d/opcache*.blacklist
; Allows exclusion of large files from being cached. By default all files
; are cached.
;opcache.max_file_size=0
; Check the cache checksum each N requests.
; The default value of "0" means that the checks are disabled.
;opcache.consistency_checks=0
; How long to wait (in seconds) for a scheduled restart to begin if the cache
; is not being accessed.
;opcache.force_restart_timeout=180
; OPcache error_log file name. Empty string assumes "stderr".
;opcache.error_log=
; All OPcache errors go to the Web server log.
; By default, only fatal errors (level 0) or errors (level 1) are logged.
; You can also enable warnings (level 2), info messages (level 3) or
; debug messages (level 4).
;opcache.log_verbosity_level=1
; Preferred Shared Memory back-end. Leave empty and let the system decide.
;opcache.preferred_memory_model=
; Protect the shared memory from unexpected writing during script execution.
; Useful for internal debugging only.
;opcache.protect_memory=0' > /etc/php5/mods-available/opcache.ini

echo -e "[www]
user = www-data
group = www-data
listen = 127.0.0.1:9000
listen.backlog = -1
listen.owner = www-data
listen.group = www-data
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 5000
slowlog = /var/log/php5-fpm.slow
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
php_value[session.save_path]    = /var/lib/php5/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php5/wsdlcache" > /etc/php5/fpm/pool.d/www.conf



# php config 
PhpIni=/etc/php5/apache2/php.ini
sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
sed -i "s/;opcache.use_cwd = 1/opcache.use_cwd = 1/" $PhpIni
sed -i "s/;opcache.validate_timestamps = 1/opcache.validate_timestamps = 1/" $PhpIni
sed -i "s/;opcache.save_comments = 1/opcache.save_comments = 1/" $PhpIni
sed -i "s/;opcache.enable_file_override = 0/opcache.enable_file_override = 0/" $PhpIni
sed -i "s/;opcache.enable = 0/opcache.enable = 1/" $PhpIni
sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 256/" $PhpIni
sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 8000/" $PhpIni
sed -i "s/^;date.timezone =$/date.timezone = \"America\/Sao_Paulo\"/" $PhpIni
sed -i "s/^;default_charset = /default_charset = /" $PhpIni
sed -i "s/^upload_max_filesize = 2M/upload_max_filesize = 10M/" $PhpIni
sed -i "s/^post_max_size = 8M/post_max_size = 20M/" $PhpIni
sed -i "s/^;realpath_cache_size = 16k/realpath_cache_size = 64K/" $PhpIni
sed -i "s/^;realpath_cache_ttl = 120/realpath_cache_ttl = 3600/" $PhpIni
sed -i "s/^max_execution_time = 30/max_execution_time = 120/" $PhpIni

PhpFpm=/etc/php5/fpm/php-fpm.conf
sed -i "s/^;emergency_restart_threshold = 0/emergency_restart_threshold = 10/" $PhpFpm
sed -i "s/^;emergency_restart_interval = 0/emergency_restart_interval = 1m/" $PhpFpm
sed -i "s/^;process_control_timeout = 0/process_control_timeout = 10/" $PhpFpm
sed -i "s/^;daemonize = yes/daemonize = yes/" $PhpFpm
sed -i "s/^;events.mechanism = epoll/events.mechanism = epoll/" $PhpFpm
sed -i "s/^;emergency_restart_threshold = 0/emergency_restart_threshold = 10/" $PhpFpm
sed -i "s/^;emergency_restart_interval = 0/emergency_restart_interval = 1m/" $PhpFpm
sed -i "s/^;process_control_timeout = 0/process_control_timeout = 10/" $PhpFpm
sed -i "s/^;daemonize = yes/daemonize = yes/" $PhpFpm
sed -i "s/^;events.mechanism = epoll/events.mechanism = epoll/" $PhpFpm

sudo chown -R www-data:azureadmin /moodle
sudo chmod 770 -R /moodle/

sudo a2enmod actions fastcgi alias
sudo a2enconf php5-fpm

# restart Apache
sudo service apache2 restart
sudo service php5-fpm restart