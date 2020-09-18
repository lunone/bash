# 建立文件夹
mkdir -p /www/v2ray
# 转到
cd /www/v2ray
# 下载解压
wget --no-check-certificate "https://github.com/v2ray/v2ray-core/releases/download/v4.22.1/v2ray-linux-64.zip" 
# 解压
unzip v2ray-linux-64.zip
# 生成uuid
uuid=`/www/v2ray/v2ctl uuid`
stty erase '^H' && read -e -p "请输入：" path
# config
echo '{
    "log": {
        "loglevel": "info"
    },
    "inbounds": [
        {
            "protocol": "vmess",
            "port": 10000,
            "listen": "127.0.0.1",
            "settings": {
                "clients": [
                    {
                        "alterId": 64,
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${path}"
                }
            }
        }
    ],
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom"
        }
    ]
}' > /www/v2ray/config.json
# systemd
echo "[Unit]
Description=V2Ray Service
After=network.target
Wants=network.target

[Service]
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting the following two lines, this service will run as user v2ray/v2ray.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
# User=v2ray
# Group=v2ray
Type=simple
PIDFile=/run/v2ray.pid
ExecStart=/www/v2ray/v2ray -config /www/v2ray/config.json
Restart=on-failure
# Don't restart in the case of configuration error
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target" > /www/v2ray/systemd/v2ray.service
# 启动
systemctl start v2ray
# 开机
systemctl enable v2ray
# 输出
echo uuid： echo ${uuid}
echo alterId： 64
echo path: ${path}
