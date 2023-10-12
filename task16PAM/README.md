
#### Задание

Запретить всем пользователям, кроме группы admin, логин в выходные (суббота и воскресенье), без учета праздников
В vagrantfile будем использовать образ centos/8 версии 2011.0
```
[vagrant@pam ~]$ uname -r
4.18.0-240.1.1.el8_3.x86_64
[vagrant@pam ~]$ cat /etc/centos-release
CentOS Linux release 8.3.2011
```

Подключаемся к тестовой ВМ, команды производим из под суперпользователя.
```
sudo -i
```
Добавим двух пользователей otusadm и otus

```
sudo useradd otusadm && sudo useradd otus
```

Проверим:
```
[root@pam ~]# cat /etc/shadow | grep otus
otusadm:!!:19642:0:99999:7:::
otus:!!:19642:0:99999:7:::
```
Настроим пароли пользователям:
```
echo "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
```
Снова проверим:
```
[root@pam ~]# cat /etc/shadow | grep otus
otusadm:$6$2dUscXXqXfsRWHSN$aEFKlxKZg6YlUHoymTh1iKZ6hNy62vl/XpPgMga0OI44bjDC/GZl3uMNaWJn5firzKJq.36./WYix2JvTfKg/.:19642:0:99999:7:::
otus:$6$/YusmflX5ZqozWci$RXVjju6PpxbNrOG.gWJjE.y0SfnRsOphaILzWv7qh6bI6iKIFhAOUoXNMJpztP312NNRNNX/b2Jouku49cfgT1:19642:0:99999:7:::
```

Создадим группу и добавим в нее пользователей root,vagrant и otusadm:
```
sudo groupadd -f admin

usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
```
Проверим:
```
[root@pam ~]# cat /etc/group | grep admin
printadmin:x:994:
admin:x:1003:otusadm,root,vagrant
```
Теперь попробуем залогиниться пользователем otus и проверим:
![Alt text](https://github.com/catalist3/otus/blob/master/task16PAM/ssh_login_otus.png?raw=true)

```
[root@pam ~]# who
vagrant  pts/0        Oct 12 13:09 (10.0.2.2)
otus     pts/1        Oct 12 13:41 (192.168.57.1)
```
Для контроля доступа пользователей будем использовать модуль pam_exec и скрипт login.sh. Скрипт расположим по пути /usr/local/bin и добавим права на исполнение. Скрипт будет сверять день и наличие пользователя в группе admin.
В случае если этот день Суббота или Воскресенье и пользователь не входит в группу admin то ему будет запрещен вход на сервер. Такой пользователь в нашем примере это otus.

Добавим в файл /etc/pam.d/sshd нашу настройку.
![Alt text](https://github.com/catalist3/otus/blob/master/task16PAM/pam_sshd.png?raw=true)

Для проверки работы схемы изменим время на тестовой ВМ.
```
sudo date 082712302022.00
```
Проверим вход на сервер под пользователем otusadm:

![Alt text](https://github.com/catalist3/otus/blob/master/task16PAM/otusadm_login.png?raw=true)

А теперь попробуем пользователем otus:

![Alt text](https://github.com/catalist3/otus/blob/master/task16PAM/otus_user_nologin.png?raw=true)