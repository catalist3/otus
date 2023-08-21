#! /bin/bash
# create file config service
touch /etc/sysconfig/watchlog
cat > /etc/sysconfig/watchlog <<\eof
# Configuration file for my watchlog service
# Place it to /etc/sysconfig

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
eof
# create test file with test word
touch /var/log/watchlog.log
cat > /var/log/watchlog.log <<\eof
ALERT
"ALERT"
TUT 
TAM
eof

# create script for logger start
touch /opt/watchlog.sh
cat > /opt/watchlog.sh <<\eof
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi
eof

# right for script logger
chmod +x /opt/watchlog.sh

# create watchlog service
touch /lib/systemd/system/watchlog.service
cat > /lib/systemd/system/watchlog.service <<\eof
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
eof

#create watchlog timer
touch /lib/systemd/system/watchlog.timer

cat > /lib/systemd/system/watchlog.timer <<\eof
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
eof

systemctl start watchlog.timer
systemctl start watchlog.service


yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y

cat > /etc/sysconfig/spawn-fcgi <<\eof
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
eof

touch /etc/systemd/system/spawn-fcgi.service
cat > /etc/systemd/system/spawn-fcgi.service <<\eof
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
eof

systemctl start spawn-fcgi

# Twi Instances
cd /usr/lib/systemd/system
sed -i 's|EnvironmentFile=/etc/sysconfig/httpd|EnvironmentFile=/etc/sysconfig/httpd-%I|' httpd.service

touch /etc/sysconfig/httpd-first
cat > /etc/sysconfig/httpd-first <<\eof
# /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf
eof

touch /etc/sysconfig/httpd-second
cat > /etc/sysconfig/httpd-second <<\eof
# /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf
eof

cd /etc/httpd/conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
sed -i 's|Listen 80|Listen 8080|' /etc/httpd/conf/first.conf
printf "PidFile /var/run/httpd-first.pid" >> /etc/httpd/conf/first.conf

cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
sed -i 's|Listen 80|Listen 8081|' /etc/httpd/conf/second.conf
printf "PidFile /var/run/httpd-second.pid" >>  /etc/httpd/conf/second.conf

mv /usr/lib/systemd/system/httpd.service /usr/lib/systemd/system/httpd-@.service

systemctl daemon-reload

setenforce 0
systemctl start httpd-@first.service
systemctl start httpd-@second.service