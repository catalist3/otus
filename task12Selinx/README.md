Практика с SELinux Цель: Тренируем умение работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется.

1)Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux. 

1) Обеспечить работоспособность приложения при включенном selinux.
 - Развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/blob/master/selinux_dns_problems/
 - Выяснить причину неработоспособности механизма обновления зоны (см. README);
 - Предложить решение (или решения) для данной проблемы;
 - Выбрать одно из решений для реализации, предварительно обосновав выбор;
 - Реализовать выбранное решение и продемонстрировать его работоспособность.

 ВЫПОЛНЕНИЕ задачи номер 1:
 При развертывании ВМ из vagrantfile веб-сервер nginx ожидаемо не запустится ввиду работающего и настроенного по умолчанию сервиса Selinux.
 ![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ErrorStartNginx.png?raw=true)

 Заходим в ВМ: vagrant ssh
 Дальнейшие действия выполняются от пользователя root.

Провери статус файерволла, корректность конфигурации Nginx и режим работы Selinux:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/Statuses.png?raw=true)
Видим что файерволл не запущен, конфигурация веб-сервера в норме, режим работы Selinux в статусе Enforcing, что означает что он будет блокировать запрещенную активность.

Для дальнейшей работы нам понадобится набор утилит для управления политиками, установим его: yum -y install policycoreutils-python
Найдем в логах (/var/log/audit/audit.log) информацию о блокировании порта и с помощью утилиты audit2why почему трафик блокируется и что нам необходимо предпринять для решения проблемы:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/audit.png?raw=true)
Утилита audit2why рекомендует выполнить команду setsebool -P nis_enabled 1, ключ -P(видимо от слова permanent)позволит сохранить правило и после перезагрузки. Последуем его рекомендациям, перезапустим веб-сервер и прверим его статус:
[root@selinux ~]# setsebool -P nis_enabled on

[root@selinux ~]# systemctl restart nginx

[root@selinux ~]# systemctl status nginx

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus1.png?raw=true)
И в браузере глянем:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/browserstatus.png?raw=true)
Вернем всё как было с помощью команды setsebool -P nis_enabled off 

Проверить статус параметра можно командой getsebool -a | grep nis_enabled 

[root@selinux ~]# setsebool -P nis_enabled off 

[root@selinux ~]# getsebool -a | grep nis_enabled 

nis_enabled --> off

Попробуем разрешить работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип:
Узнаем используемый тип для портов веб-сервера и добавим наш целевой порт в этот тип:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/port_to_type.png?raw=true)
ПЕрезапустим веб-сервер и проверим статус:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus2.png?raw=true)
Удалим порт из типа,и попытаемся перезапустить веб-сервер:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus3.png?raw=true)

На этом этапе веб-сервер запускаться не будет, его блокирует Selinux.

Далее воспользуемся утилитой audit2allow чтобы на основе логов SELinux сделать модуль, который разрешит работу nginx на нестандартном порту:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/allowmodule.png?raw=true)

С помощью команды semodule -i nginx.pp применим сформированный модуль.
Запустим веб-сервер и проверим его статус:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus4.png?raw=true)

Необходимо отметить что применение модуля сохраняет возможность запуска веб-сервер и после перезагрузки.
Чтобы удалить модуль, надо выполнить команду semodule -r httpd_add. Чтобы выключить модуль semodule -d -v httpd_add. Включить модуль semodule -e -v httpd_add


2. Обеспечение работоспособности приложения при включенном SELinux

Выполним клонирование репозитория: git clone https://github.com/mbfx/otus-linux-adm.git со стендом из двух машин.
Запускаем наши виртуальные машины.

Подключаемся к клиентской машине vagrant ssh client и пробуем выполнить команды для внесения изменений в зону:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/eneterDNSlab.png?raw=true)

В качестве результата при попытке внести изменения в зону получаем  - update failed: SERVFAIL
Снова воспользуемся утилитой audit2why для анализа логов
Вводим команду cat /var/log/audit/audit.log | audit2why и не получив в ответ ничего понимаем, что ошибок на клиенте нет. Идем на сервер.

Проверим события запрета в логах: cat /var/log/audit/audit.log | grep denied

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/grepauditlog.png?raw=true)

Посмтотрим что покажет утилита sealert: команда - sealert -a /var/log/audit/audit.log

<details>
  <summary>Результат применения команды:</summary>

  ```
  94% donetype=AVC msg=audit(1694204151.954:1932): avc:  denied  { write } for  pid=5181 comm="isc-worker0000" name="named" dev="sda1" ino=67552240 scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:named_zone_t:s0 tclass=dir permissive=0
 
**** Invalid AVC allowed in current policy ***

100% done
found 1 alerts in /var/log/audit/audit.log
--------------------------------------------------------------------------------

SELinux is preventing /usr/sbin/named from create access on the file named.ddns.lab.view1.jnl.

*****  Plugin catchall_labels (83.8 confidence) suggests   *******************

If you want to allow named to have create access on the named.ddns.lab.view1.jnl file
Then you need to change the label on named.ddns.lab.view1.jnl
Do
# semanage fcontext -a -t FILE_TYPE 'named.ddns.lab.view1.jnl'
where FILE_TYPE is one of the following: dnssec_trigger_var_run_t, ipa_var_lib_t, krb5_host_rcache_t, krb5_keytab_t, named_cache_t, named_log_t, named_tmp_t, named_var_run_t, named_zone_t.
Then execute:
restorecon -v 'named.ddns.lab.view1.jnl'


*****  Plugin catchall (17.1 confidence) suggests   **************************

If you believe that named should be allowed create access on the named.ddns.lab.view1.jnl file by default.
Then you should report this as a bug.
You can generate a local policy module to allow this access.
Do
allow this access for now by executing:
# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000
# semodule -i my-iscworker0000.pp


Additional Information:
Source Context                system_u:system_r:named_t:s0
Target Context                system_u:object_r:etc_t:s0
Target Objects                named.ddns.lab.view1.jnl [ file ]
Source                        isc-worker0000
Source Path                   /usr/sbin/named
Port                          <Unknown>
Host                          <Unknown>
Source RPM Packages           bind-9.11.4-26.P2.el7_9.14.x86_64
Target RPM Packages           
Policy RPM                    selinux-policy-3.13.1-266.el7.noarch
Selinux Enabled               True
Policy Type                   targeted
Enforcing Mode                Enforcing
Host Name                     ns01
Platform                      Linux ns01 3.10.0-1127.el7.x86_64 #1 SMP Tue Mar
                              31 23:36:51 UTC 2020 x86_64 x86_64
Alert Count                   1
First Seen                    2023-09-08 20:33:13 UTC
Last Seen                     2023-09-08 20:33:13 UTC
Local ID                      821db288-5719-408f-9408-a92f0fc2279d

Raw Audit Messages
type=AVC msg=audit(1694205193.577:1968): avc:  denied  { create } for  pid=5181 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0


type=SYSCALL msg=audit(1694205193.577:1968): arch=x86_64 syscall=open success=no exit=EACCES a0=7fe513db8050 a1=241 a2=1b6 a3=24 items=0 ppid=1 pid=5181 auid=4294967295 uid=25 gid=25 euid=25 suid=25 fsuid=25 egid=25 sgid=25 fsgid=25 tty=(none) ses=4294967295 comm=isc-worker0000 exe=/usr/sbin/named subj=system_u:system_r:named_t:s0 key=(null)

Hash: isc-worker0000,named_t,etc_t,file,create

```

</details>

Строка SELinux is preventing /usr/sbin/named from create access on the file named.ddns.lab.view1.jnl говорит нам, что субьект named не может изменить файл named.ddns.lab.view1.jnl как результат работы SELinux.
Тут же приводятся два возможных варианта  решения возникшей проблемы. Попробуем решить изменение контекста файла named.ddns.lab.view1.jnl, поскольку создание модуля может дать полномочия большие чем необходимо.

Найдем расположение файла named.ddns.lab.view1 
[root@ns01 ~]# find /etc/named/ -type f -name named.ddns.lab.view1
/etc/named/dynamic/named.ddns.lab.view1
Узнаем контекст безопасности у файла:

[root@ns01 ~]# ll -Z /etc/named/dynamic/named.ddns.lab.view1
-rw-r--r--. named named system_u:object_r:etc_t:s0 /etc/named/dynamic/named.ddns.lab.view1

Согласно документации для директории /etc/named/dynamic тип по умолчанию установлен как named_cache_t
<details>
  <summary>Список:</summary>
```
named_cache_t
/var/named/data(/.*)?
/var/named/slaves(/.*)?
/var/named/dynamic(/.*)?
/var/named/chroot/var/tmp(/.*)?
/var/named/chroot/var/named/data(/.*)?
/var/named/chroot/var/named/slaves(/.*)?
/var/named/chroot/var/named/dynamic(/.*)?
```
</details>

На основе этой информации изменим тип в контексте

<details>
  <summary>Изменения типа контекста:</summary>
```
[root@ns01 ~]# semanage fcontext -a -t named_cache_t '/etc/named/dynamic(/.*)?'
[root@ns01 ~]# restorecon -R -v /etc/named/dynamic/
restorecon reset /etc/named/dynamic context unconfined_u:object_r:etc_t:s0->unconfined_u:object_r:named_cache_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab.view1 context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0
```
</details>

Проверим возможность изменить файл зоны.
<details>
  <summary>Обновление зоны:</summary>
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
</details>

<details>
  <summary>Проверка:</summary>
[vagrant@client ~]$ dig www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.14 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 22679
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; AUTHORITY SECTION:
ddns.lab.		3600	IN	NS	ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10

;; Query time: 14 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Sep 08 21:47:27 UTC 2023
;; MSG SIZE  rcvd: 96
</details>
