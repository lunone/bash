#!/bin/sh

echo '更新系统中，时间稍长请勿中断...'
yum -y update >/dev/null 2>&1
echo '安装wget unzip e2fsprogs ……'
yum -y install wget unzip e2fsprogs vixie-cron crontabs >/dev/null 2>&1
#vixie-cron软件包是cron的主程序；crontabs软件包是用来安装、卸装、或列举用来驱动 cron 守护进程的表格的程序

mkdir -p /www/.config
mkdir -p /www/.log
echo '提前确保域名要被解析,请输入域名，不带http(s)://部分'
stty erase '^H' && read -e -p "请输入：" domain
echo ":80 {
	gzip
	root /www/site/${domain}
	internal /app
	log /www/.log/${domain}.log {
	    rotate_size 30
	    rotate_age  30
	    rotate_keep 10
	    rotate_compress
	}
	fastcgi / 127.0.0.1:9000 php # php variant only
}" > /www/.config/Caddyfile

echo '安装caddy'
#caddy官方脚本
curl https://getcaddy.com | bash -s personal
echo '[Unit]
Description=Caddy server
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/var/run/caddy.pid
ExecStart=/usr/local/bin/caddy -conf=/www/.config/Caddyfile -agree=true 
RestartPreventExitStatus=23
Restart=always
User=root

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/caddy.service

echo '安装php'
yum install -y epel-release  yum-utils
yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum  --enablerepo=remi-php73 install -y php-cgi php-fpm php-curl php-gd php-mbstring php-xml php-sqlite3 sqlite-devel php-mysqli
mv -f /etc/php.ini /www/.config/php.ini.old
echo '[PHP]
short_open_tag = On
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
serialize_precision = 17
zend.enable_gc = On
expose_php = On
max_execution_time = 90
max_input_time = 60
memory_limit = 128M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = On
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 8M
default_mimetype = "text/html"
default_charset = "UTF-8"
enable_dl = Off
file_uploads = On
open_basedir = /www/site:/tmp/:/proc/
upload_max_filesize = 6M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60' > /www/.config/php.ini
ln -s  /www/.config/php.ini /etc/php.ini

echo '启动php'
systemctl start php-fpm
systemctl enable php-fpm

echo '启动caddy'
systemctl start caddy
systemctl stop caddy

echo '生成主页'
echo '<?php 
phpinfo();' > /www/site/${domain}/index.php


echo '安装可道云'
mkdir -p /www/site/${domain}/dir
curl -o /www/site/${domain}/dir/kod.zip http://static.kodcloud.com/update/download/kodexplorer4.40.zip
unzip -o /www/site/${domain}/dir/kod.zip -d /www/site/${domain}/dir >/dev/null 2>&1
rm -f /www/site/${domain}/dir/kod.zip

# 因为php默认是以apache用户执行的，所以把www/site文件夹给apache，并755
chown -Rf apache:apache /www/site
chmod -Rf 755 /www/site/${domain}/dir

echo '添加caddy和php的守护进程'
# 添加cron文件夹
mkdir -p /root/.cron
# 增加守护文件
echo '#!/bin/sh

#caddy
count=`ps -ef|grep caddy|grep -v grep`
if [ "$count" == "" ]; then
systemctl restart caddy
fi

#php
count=`ps -ef|grep php-fpm|grep -v grep`
if [ "$count" == "" ]; then
systemctl restart php-fpm
fi' > /root/.cron/guardian.sh
# 添加执行权限
chmod +x /root/.cron/guardian.sh
# 怕万一不支持chattr，安装支持chattr的

# 防删补丁
chattr +i /root/.cron/guardian.sh

echo '添加守护任务定时执行'
echo '*/10 * * * * /root/.cron/guardian.sh > /dev/null 2>&1 &' >> /etc/crontab

echo '开始安装python3.6'
# python 
yum -y install epel-release sqlite  sqlite-devel
sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum -y install python36  python36u-pip
python3.6  -m  pip install --upgrade pip
mv   /usr/bin/python  /tmp/
ln -s /usr/bin/python3.6    /usr/bin/python

sed  -i    's/\#\!\/usr\/bin\/python/\#\!\/usr\/bin\/python2/'   /usr/bin/yum
sed  -i    's/\#\! \/usr\/bin\/python/\#\! \/usr\/bin\/python2/'   /usr/libexec/urlgrabber-ext-down
