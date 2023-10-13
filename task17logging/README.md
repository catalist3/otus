
#### Описание домашнего задания
1. В Vagrant разворачиваем 2 виртуальные машины web и log
2. на web настраиваем nginx
3. на log настраиваем центральный лог сервер на любой системе на выбор
journald;
rsyslog;
elk.
4. настраиваем аудит, следящий за изменением конфигов nginx 


На основе файла Vagrant разворачиваем тестовую среду из двух ВМ, web и log. Начнем с ВМ web.
Дальнейшие действия выполняем из под суперпользователя.

Устанавливаем часовой пояс Europe/Moscow. Перезапускаем службу NTP и проверяем время:
```
[root@web ~]# date
Fri Oct 13 12:53:38 MSK 2023

[root@web ~]# systemctl status chronyd
● chronyd.service - NTP client/server
   Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2023-10-13 12:53:32 MSK; 1min 2s ago
     Docs: man:chronyd(8)
           man:chrony.conf(5)
  Process: 3408 ExecStartPost=/usr/libexec/chrony-helper update-daemon (code=exited, status=0/SUCCESS)
  Process: 3403 ExecStart=/usr/sbin/chronyd $OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 3405 (chronyd)
   CGroup: /system.slice/chronyd.service
           └─3405 /usr/sbin/chronyd

Oct 13 12:53:32 web systemd[1]: Starting NTP client/server...
Oct 13 12:53:32 web chronyd[3405]: chronyd version 3.4 starting (+CMDMON +NTP +REFCLOCK +RTC +PRIVDROP +SCFILTER +SIGND +ASYNCDNS +... +DEBUG)
Oct 13 12:53:32 web chronyd[3405]: Frequency -29.174 +/- 0.475 ppm read from /var/lib/chrony/drift
Oct 13 12:53:32 web systemd[1]: Started NTP client/server.
Oct 13 12:53:38 web chronyd[3405]: Selected source 91.209.94.10
```
#### Время необходимо выровнять на обеих ВМ.

#### Установим nginx на виртуальной машине web
Подключим репозиторий...
```
yum install epel-release 
```
И установим веб-сервер.
```
yum install -y nginx
```
Запустим сервис и проверим:

![Alt text](https://github.com/catalist3/otus/blob/master/task17logging/nginx_status.png?raw=true)

[root@web ~]# rpm -qa | grep nginx
nginx-filesystem-1.20.1-10.el7.noarch
nginx-1.20.1-10.el7.x86_64


[root@log rsyslog]# cat /var/log/rsyslog/web/nginx_error.log
Oct 13 14:51:16 web nginx_error: 2023/10/13 14:51:16 [error] 22336#22336: *2 open() "/usr/share/nginx/html/netadm" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /netadm HTTP/1.1", host: "192.168.50.10"