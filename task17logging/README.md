
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



[root@log rsyslog]# cat /var/log/rsyslog/web/nginx_error.log
Oct 13 14:51:16 web nginx_error: 2023/10/13 14:51:16 [error] 22336#22336: *2 open() "/usr/share/nginx/html/netadm" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /netadm HTTP/1.1", host: "192.168.50.10"