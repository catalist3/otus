
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

Для полноты картины глянем на основную страницу

![Alt text](https://github.com/catalist3/otus/blob/master/task17logging/web_page_nginx.png?raw=true)

#### Переходим к настройке центрального сервера сбора логов
Действия производим также из под суперпользователя.
Сервис rsyslog уже должен присутствовать в системе, необходимо проверить его версию.

![Alt text](https://github.com/catalist3/otus/blob/master/task17logging/rsyslog_install_version.png?raw=true)

Настриваем работу сервиса для сбора логов с удаленных машин, для чего вносим изменения в файл настроек /etc/rsyslog.conf. Разрешаем сервису собирать логи на 514 порту(как TCP так и UDP) и добавляем правило приёма сообщений от удаленных хостов.
```
 Provides UDP syslog reception
$ModLoad imudp
$UDPServerRun 514

# Provides TCP syslog reception
$ModLoad imtcp
$InputTCPServerRun 514

........................

#Add remote logs
$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~

```
Перезапустим сервис и проверим что порты 514 в работе:

![Alt text](https://github.com/catalist3/otus/blob/master/task17logging/rsyslog_status_ports.png?raw=true)



После чего вернемся на веб-сервер и настроим его для отправки логов на центральный лог-сервер.
Для чего внесем изменения в файл конфигурации веб-сервера /etc/nginx/nginx.conf. Добавим в раздел настроек логирования следующие строки:
```
error_log syslog:server=192.168.50.15:514,tag=nginx_error;
access_log syslog:server=192.168.50.15:514,tag=nginx_access,severity=info combined;
```
Таким образом мы сказали веб-серверу отправлять события доступа и сообщения об ошибках на удаленный ервер сбора логов. Также с помощью директивы tag разделили события по разным файлам.
После чего необходимо проверить корректность настроек и перезапустить веб-сервер:

```
[root@web ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@web ~]# systemctl restart nginx
```
В целях проверки обновим несколько раз основную веб-страницу и, для регитрации ошибки попробуем обратиться к несуществующей странице.
```
[root@log /]# cat /var/log/rsyslog/web/nginx_error.log
Oct 13 14:51:16 web nginx_error: 2023/10/13 14:51:16 [error] 22336#22336: *2 open() "/usr/share/nginx/html/netadm" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /netadm HTTP/1.1", host: "192.168.50.10"
[root@log /]# cat /var/log/rsyslog/web/nginx_access.log
Oct 13 14:48:31 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:31 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:48:32 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:32 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:48:32 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:32 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:48:33 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:33 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:48:33 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:33 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:48:33 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:48:33 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:51:16 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:51:16 +0300] "GET /netadm HTTP/1.1" 404 3650 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:51:16 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:51:16 +0300] "GET /poweredby.png HTTP/1.1" 200 368 "http://192.168.50.10/netadm" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
Oct 13 14:51:16 web nginx_access: 192.168.50.1 - - [13/Oct/2023:14:51:16 +0300] "GET /nginx-logo.png HTTP/1.1" 200 368 "http://192.168.50.10/netadm" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0"
```

#### Настройка аудита, контролирующего изменения конфигурации nginx

Утилита audit отвечающая за контроль изменений конфигурации обычно уже присутствует в составе ОС.
Проверим это:
``` 
[root@web ~]# rpm -qa | grep audit
audit-2.8.5-4.el7.x86_64
audit-libs-2.8.5-4.el7.x86_64
```
Для отслеживания изменений в конфигруации nginx добавим настройки в файл с правилами /etc/audit/rules.d/audit.rules:
```
-w /etc/nginx/nginx.conf -p wa -k nginx.conf
-w /etc/nginx/default.d/ -p wa -k nginx.conf
```
Данные инструкции настраивают контроль на запись и изменение атрибутов в файле /etc/nginx/nginx.conf и файлов в директории /etc/nginx/default.d. 

Далее перезапустим сервис и проверим работу аудита с помощью утилиты ausearch, перед этим внесем некоторые изменения в файл конфигурации веб-сервера.
```
[root@web /]# ausearch -f /etc/nginx/nginx.conf
----
time->Fri Oct 13 18:14:56 2023
type=CONFIG_CHANGE msg=audit(1697210096.850:1100): auid=1000 ses=4 op=updated_rules path="/etc/nginx/nginx.conf" key="nginx.conf" list=4 res=1
----
time->Fri Oct 13 18:14:56 2023
type=PROCTITLE msg=audit(1697210096.850:1101): proctitle=7669002F6574632F6E67696E782F6E67696E782E636F6E66
type=PATH msg=audit(1697210096.850:1101): item=3 name="/etc/nginx/nginx.conf~" inode=12488 dev=08:01 mode=0100644 ouid=0 ogid=0 rdev=00:00 obj=system_u:object_r:httpd_config_t:s0 objtype=CREATE cap_fp=0000000000000000 cap_fi=0000000000000000 cap_fe=0 cap_fver=0
type=PATH msg=audit(1697210096.850:1101): item=2 name="/etc/nginx/nginx.conf" inode=12488 dev=08:01 mode=0100644 ouid=0 ogid=0 rdev=00:00 obj=system_u:object_r:httpd_config_t:s0 objtype=DELETE cap_fp=0000000000000000 cap_fi=0000000000000000 cap_fe=0 cap_fver=0
type=PATH msg=audit(1697210096.850:1101): item=1 name="/etc/nginx/" inode=85 dev=08:01 mode=040755 ouid=0 ogid=0 rdev=00:00 obj=system_u:object_r:httpd_config_t:s0 objtype=PARENT cap_fp=0000000000000000 cap_fi=0000000000000000 cap_fe=0 cap_fver=0
type=PATH msg=audit(1697210096.850:1101): item=0 name="/etc/nginx/" inode=85 dev=08:01 mode=040755 ouid=0 ogid=0 rdev=00:00 obj=system_u:object_r:httpd_config_t:s0 objtype=PARENT cap_fp=0000000000000000 cap_fi=0000000000000000 cap_fe=0 cap_fver=0
type=CWD msg=audit(1697210096.850:1101):  cwd="/"
type=SYSCALL msg=audit(1697210096.850:1101): arch=c000003e syscall=82 success=yes exit=0 a0=252ea20 a1=253ad10 a2=fffffffffffffe80 a3=7ffcba3e6020 items=4 ppid=3363 pid=22486 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts0 ses=4 comm="vi" exe="/usr/bin/vi" subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key="nginx.conf"
----
```

Теперь попробуем настроить логов аудита на централизованный сервер. Для этого потребуется установить плагин audispd-plugins.
```
yum -y install audispd-plugins
```
После установки откорректируем файл /etc/audit/auditd.conf, изменив инструкцию name_format на HOSTNAME

Параметр active в файле /etc/audisp/plugins.d/au-remote.conf поменяем на yes.

В файле /etc/audisp/audisp-remote.conf в инструкции remote_server адрес нашего централизованного сервера логов. После настроек перезапустим сервис auditd
```
service auditd restart
```

На лог-сервере  в файле /etc/audit/auditd.conf раскомментируем строку:
```
tcp_listen_port = 60
```

Вернемся на веб-сервер, сделаем какие-либо изменения в файле конфигурации веб-сервера, после чего проверим получение информации на лог-сервере:
```
[root@log /]# grep web /var/log/audit/audit.log 
node=web type=DAEMON_START msg=audit(1697212704.315:9833): op=start ver=2.8.5 format=raw kernel=3.10.0-1127.el7.x86_64 auid=4294967295 pid=22652 uid=0 ses=4294967295 subj=system_u:system_r:auditd_t:s0 res=success
node=web type=CONFIG_CHANGE msg=audit(1697212704.563:1146): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=remove_rule key="nginx_conf" list=4 res=1
node=web type=CONFIG_CHANGE msg=audit(1697212704.564:1147): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=remove_rule key="nginx_conf" list=4 res=1
node=web type=CONFIG_CHANGE msg=audit(1697212704.564:1148): audit_backlog_limit=8192 old=8192 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=CONFIG_CHANGE msg=audit(1697212704.566:1149): audit_failure=1 old=1 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=CONFIG_CHANGE msg=audit(1697212704.567:1150): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
node=web type=CONFIG_CHANGE msg=audit(1697212704.573:1151): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1

...........................................
```