echo '安装docker'
echo -e "正在为 Centos7 更新源"
yum update -y
echo -e "卸载旧的docker及依赖"
yum remove docker docker-common docker-selinux docker-engine -y
yum install -y yum-utils device-mapper-persistent-data lvm2 -y
echo -e "安装docker"
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce -y
echo -e "docker安装完毕，运行docker并设置开机启动"
systemctl start docker
systemctl enable docker
echo '安装wget'
yum install wget -y 
echo -e "安装docker管理面板portainer"
docker run -d -p 9000:9000 --restart=always -v /var/run/docker.sock:/var/run/docker.sock --name prtainer  portainer/portainer
echo '安装caddy'
echo '提前确保域名要被解析,请输入域名，不带http(s)://部分'
stty erase '^H' && read -e -p "请输入：" domain
# 新建一堆文件夹，防止docker挂载文件成文件夹
mkdir /www
mkdir /www/.caddy
echo "${domain} {
	gzip
	tls lunone@qq.com
	fastcgi / 127.0.0.1:9000 php # php variant only
    on startup php-fpm7 # php variant only
}" > /www/Caddyfile
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
upload_max_filesize = 6M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60' > /www/php.ini
#
docker run -d --name=caddy --restart=always -e ACME_AGREE=true -v /www/Caddyfile:/etc/Caddyfile -v /www/.caddy:/root/.caddy -v /www/site:/srv -v /www/php.ini:/etc/php7/php.ini -p 80:80 -p 443:443 -p 2015:2015 abiosoft/caddy:php
#
echo '访问一次域名来获取ssl证书，给后面的webssh用'
curl https://${domain}
echo '生成空的filebrowser.db'
> /root/.config/filebrowser.db
echo '安装filebrowser,默认的用户名密码是admin:admin'
docker run -d --name=filebrowser -v /:/srv -v /root/.config/filebrowser.db:/database.db -p 8080:80 filebrowser/filebrowser
echo '安装ftp的docker'
stty erase '^H' && read -e -p "请输入 用户名：" ftpUser
stty erase '^H' && read -e -p "请输入 密码：" ftpPass
stty erase '^H' && read -e -p "请输入 服务器ip：" ftpDomain
docker run -d -v /www/site/applun.com:/home/vsftpd -p 20-20:21-21 -p 47400-47470:47400-47470 -e FTP_USER=${ftpUser} -e FTP_PASS=${ftpPass} 
-e PASV_ADDRESS=${ftpDomain} --name ftp --restart=always bogem/ftp
echo '安装数据库mariaDB'
stty erase '^H' && read -e -p "请输入ROOT用户名：" dbRootPass
stty erase '^H' && read -e -p "请输入 数据库名：" dbName
stty erase '^H' && read -e -p "请输入 用户名：" dbUser
stty erase '^H' && read -e -p "请输入 用户名：" dbPass
docker run -d --name mysql -p 3306:3306 -v /db:/var/lib/mysql -e MYSQL_DATABASE=${dbName} -e MYSQL_USER=${dbUser} -e MYSQL_PASSWORD=${dbPass} -e MYSQL_ROOT_PASSWORD=${dbRootPass} yobasystems/alpine-mariadb --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

echo '安装web ssh软件sshwifty'
stty erase '^H' && read -e -p "请输入SSH面板访问密码：" sshPass
# 安装sshwifty
echo '下载sshwifty'
cd ~
mkdir /root/sshwifty
cd sshwifty
curl -L  https://github.com/niruix/sshwifty/releases/download/0.1.13-beta-release-prebuild/sshwifty_0.1.13-beta-release_linux_amd64.tar.gz | tar zx
mv sshwifty_linux_amd64 /bin/sshwifty
echo '清理临时文件'
rm -rf /root/sshwifty
echo '建立/root/.config文件夹'
mkdir /root/.config
echo '{
  "HostName": "",
  "SharedKey": "${sshPass}",
  "DialTimeout": 5,
  "Socks5": "",
  "Socks5User": "",
  "Socks5Password": "",
  "Servers": [
    {
      "ListenInterface": "0.0.0.0",
      "ListenPort": 8443,
      "InitialTimeout": 3,
      "ReadTimeout": 60,
      "WriteTimeout": 60,
      "HeartbeatTimeout": 20,
      "ReadDelay": 10,
      "WriteDelay": 10,
      "TLSCertificateFile": "/www/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.crt",
      "TLSCertificateKeyFile": "/www/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.key"
    }
  ]
}' > /root/.config/sshwifty.conf.json

echo '[Unit]
Description=sshwifty
After=network.target

[Service]
ExecStart=/bin/sshwifty
ExecStop=/bin/killall sshwifty

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/webssh.service


