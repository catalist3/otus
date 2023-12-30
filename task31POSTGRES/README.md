#### Описание домашнего задания
1) Настроить hot_standby репликацию с использованием слотов<br />
2) Настроить правильное резервное копирование<br />

Использовать будем образ ```centos/8``` вместо ```centos/stream8```. С ним как обычно какая-то фигня, не скачивается с репозитория.<br />
После развертывания ВМ указанных в Vagrantfile необходимо будет скорректировать список репозиториев:
```
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
```

На всех хостах предварительно должны быть выключены ```firewalld``` и ```SElinux```:<br />
Отключаем службу firewalld:  ```systemctl stop firewalld```<br />
Удаляем службу из автозагрузки: ```systemctl disable firewalld```<br />
Отключаем SElinux: ```setenforce 0```<br />
Правим параметр ```SELINUX=disabled``` в файле ```/etc/selinux/config``` <br />

Настройки будем выпонять из под суперпользователя ```sudo -i```



Перед настройкой репликации необходимо установить postgres-server на хосты node1 и node2:<br />
1) Добавим postgres репозиторий: ```sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm```<br />
2) Исключаем старый postgresql модуль: ```yum -qy module disable postgresql```<br />
3) Устанавливаем postgresql-server 14: ```yum install -y postgresql14-server```<br />
4) Выполняем инициализацию кластера: ```sudo /usr/pgsql-14/bin/postgresql-14-setup initdb```<br />
5) Запускаем postgresql-server: ```systemctl start postgresql-14```<br />
6) Добавляем postgresql-server в автозагрузку:  ```systemctl enable postgresql-14```<br />


#### Сервер master

Проверим статус postgresql-14:<br />
```
[root@node1 /]# systemctl status postgresql-14
● postgresql-14.service - PostgreSQL 14 database server
   Loaded: loaded (/usr/lib/systemd/system/postgresql-14.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2023-12-26 21:31:47 UTC; 41min ago
     Docs: https://www.postgresql.org/docs/14/static/
  Process: 31333 ExecStartPre=/usr/pgsql-14/bin/postgresql-14-check-db-dir ${PGDATA} (code=exited, status=0/SUCCES>
 Main PID: 31339 (postmaster)
    Tasks: 10 (limit: 5970)
   Memory: 37.5M
   CGroup: /system.slice/postgresql-14.service
           ├─31339 /usr/pgsql-14/bin/postmaster -D /var/lib/pgsql/14/data/
           ├─31340 postgres: logger 
           ├─31342 postgres: checkpointer 
           ├─31343 postgres: background writer 
           ├─31344 postgres: walwriter 
           ├─31345 postgres: autovacuum launcher 
           ├─31346 postgres: stats collector 
           ├─31347 postgres: logical replication launcher 
           ├─31348 postgres: walsender postgres 192.168.57.12(53648) streaming 0/60000D8
           └─31367 postgres: walsender barman 192.168.57.13(40466) streaming 0/60000D8

Dec 26 21:31:44 node1 systemd[1]: Starting PostgreSQL 14 database server...
Dec 26 21:31:44 node1 postmaster[31339]: 2023-12-26 21:31:44.847 UTC [31339] LOG:  redirecting log output to loggi>
Dec 26 21:31:44 node1 postmaster[31339]: 2023-12-26 21:31:44.847 UTC [31339] HINT:  Future log output will appear >
Dec 26 21:31:47 node1 systemd[1]: Started PostgreSQL 14 database server.
```


Задаем пароль для пользователя postgres:<br />
```
[root@node1 ~]# passwd postgres   # Otus2023

[root@node1 ~]# sudo -u postgres psql -c "ALTER ROLE postgres PASSWORD 'Otus2023'"
could not change directory to "/root": Permission denied
ALTER ROLE
```

Заходим в систему под данной учетной записью и подключаемся к базе:<br />
```
su - postgres
[root@node1 ~]# su - postgres
[postgres@node1 ~]$ psql
psql (14.10)
Type "help" for help.

postgres=# 
```


Создадим базу replica<br />
```
postgres=# create database replica;
CREATE DATABASE
postgres=# 
```

Выводим список баз:<br />
<pre>
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 <b>replica   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | </b>
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)
</pre>

Создадим во вновь созданной базе таблицу, заполним ее и проверим:<br />
```
replica=# CREATE TABLE cars (id INT,name VARCHAR);
CREATE TABLE
replica=# INSERT INTO cars(id,name) VALUES(1,'Volvo');
INSERT 0 1
replica=# SELECT * FROM cars;
 id | name  
----+-------
  1 | Volvo
(1 row)

replica=# 
```


По умолчанию, сервер баз данных postresql разрешает подключение только с локального компьютера.<br />
Открываем на редактирование основной файл конфигурации postgresql.conf:<br />
```
[root@node1 ~]# vi /var/lib/pgsql/14/data/postgresql.conf
```
Разрешим принимать соединения с любых адресов и слушать запросы на стандартном порту:<br />
```
listen_addresses = '*'
port = 5432
```

Открываем на редактирование следующий конфигурационный файл pg_hba.conf:<br />
```
[root@node1 ~]# vi /var/lib/pgsql/14/data/pg_hba.conf
```
Разрешим принимать соединения с любых адресов и слушать запросы на стандартном порту:<br />
```
listen_addresses = '*'
port = 5432
```

Редактируем файл, приводим к виду:
<pre>
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
<b>host    all             all             192.168.57.0/24        scram-sha-256</b>
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
<b>host    replication     all             192.168.57.0/24        scram-sha-256</b>
host    replication     all             ::1/128                 scram-sha-256
</pre>

Проверим что сервис слушает на определенном порту:
```
[root@node1 ~]# netstat -patn
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      734/sshd            
tcp        0      0 0.0.0.0:5432            0.0.0.0:*               LISTEN      26746/postmaster    
tcp        0      0 0.0.0.0:111             0.0.0.0:*               LISTEN      1/systemd           
tcp        0      0 10.0.2.15:22            10.0.2.2:40924          ESTABLISHED 4146/sshd: vagrant  
tcp6       0      0 :::22                   :::*                    LISTEN      734/sshd            
tcp6       0      0 :::5432                 :::*                    LISTEN      26746/postmaster    
tcp6       0      0 :::111                  :::*                    LISTEN      1/systemd           
```






#### Настройка node2
Предполагаем что postgresql14-server уже настроен.
Исключения укажем по ходу настройки.

Удалим директорию postgresql:
```
[root@node2 ~]# rm -rf /var/lib/pgsql/14/data/
```
Подключаемся к базе данных на сервере node1:
```
[root@node2 ~]# sudo -u postgres pg_basebackup -h 192.168.57.11 -R -D /var/lib/pgsql/14/data -U postgres -W
could not change directory to "/root": Permission denied
Password: 
```
Запускаем сервис postresql:
```
[root@node2 ~]# systemctl enable postgresql-14 --now
Created symlink /etc/systemd/system/multi-user.target.wants/postgresql-14.service → /usr/lib/systemd/system/postgresql-14.service.
```

Проверяем работу репликации.
Подключаемся к postgresql.
```
[root@node2 ~]# sudo -i -u postgres
[postgres@node2 ~]$ psql
psql (14.10)
Type "help" for help.

postgres=# 
```
Проверим список баз:

<pre>
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
<b> replica   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | </b>
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# 

</pre>

Подключаемся к базе данных replica и проверим данные из таблицы cars:
```
postgres=# \c replica
You are now connected to database "replica" as user "postgres".
replica=# SELECT * FROM cars;
 id | name  
----+-------
  1 | Volvo
(1 row)

replica=# 
```
Видим внесенные на сервере node1 данные.

Попробуем внести данные с базу со стороны сервера node2:
```
replica=# INSERT INTO cars(id,name) VALUES(3,'Opel');
ERROR:  cannot execute INSERT in a read-only transaction
replica=# 
```
Как видно возможности не имеем.

#### Настройка резервного копирования

Настраивать резервное копирование мы будем с помощью утилиты Barman. В документации Barman рекомендуется разворачивать Barman на отдельном сервере. В этом случае потребуется настроить доступы между серверами по SSH-ключам. В данном руководстве мы будем разворачивать Barman на отдельном хосте, если Вам удобнее, для теста можно будет развернуть Barman на хосте node1.<br />

На хостах node1 и node2 необходимо установить утилиту barman-cli, для этого:<br />
Устанавливаем epel-release: ```dnf install epel-release -y``` <br />
Устанавливаем barman-cli: ```dnf install barman-cli```<br />

На хосте barman выполняем следующие настройки:<br />
*предварительно отключаем ```firewalld и SElinux```<br />
Устанавливаем epel-release: ```dnf install epel-release -y```<br />
Добавим postgres репозиторий: ```sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm```<br />
Исключаем старый postgresql модуль: ```yum -qy module disable postgresql```<br />
Устанавливаем пакеты barman и postgresql-client: ```dnf install barman-cli barman postgresql14```<br />
Переходим в пользователя barman и генерируем ssh-ключ: 
```
su barman
ssh-keygen -t rsa -b 4096
```

На хосте node1:<br />
Переходим в пользователя postgres и генерируем ssh-ключ:<br /> 
```
su postgres
cd 
ssh-keygen -t rsa -b 4096
```

После генерации ключа, выводим содержимое файла ~/.ssh/id_rsa.pub:<br />
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4h4P2dxXjCwkXKHzxX9gr23Wzu8uxLFmgz9oSSWDBKOgD9CkyJ01XTPdfOWWWL2fpWKrFu8GIVcBFjIucGw61c+auHhetOwez4x9EmtaMjgZcGeDBFu2sTD5Zuutuav/pBg9UfTuDW50DWzqH/z03vbKsOcLQgqMbgBLQaVg/WRgvgCevPHJF1P/E181A3pU4f1LBZtB/gkRKCwp23GFLPHt6OyBsUfyew2s+XLqqq06Kka8nGXmFrOF7fGSnq2Y1hYKZaK6KLnpQTThdFdBwUmhpLLO2TzI3rixxgleX/xT2yO+xc5JQ9vC4pOkYlPVQUlcaPhFD0wfmBM672IM/MfSka+mNTKYVB30NzRi8OWFmmfdftNVON0AnNAiIIElio7runEXvZSaP3LZzetCrEXSytwn9Qouj+H2lPOjSXG2mElCxaamV3WFVyk+eTqRCZZxdKcyRciMymrkFxzfukmxWK2NJbLq+UcFX3TMNoEG/2SANPfnEhJKpNtZzcWb7X2eRwoi0Cdg5nxDtIMgczUSoyTyw+vQtFdcf9isHa5gmJOmd4owCDF6V8QpjwHbsBQxKy+U9DH9inChCEHW568hObMAVfKuWZcCyLn9mAYMoUwCsrIVIUNn+6jfA5tuToGNah/9Zs2Wuja52E622K529iDot93+xWxiEtWwA1Q== postgres@node1
```

Копируем содержимое файла на сервер barman в файл /var/lib/barman/.ssh/authorized_keys

В psql создаём пользователя barman c правами суперпользователя:
```CREATE USER barman WITH REPLICATION Encrypted PASSWORD 'Otus2023';```

В файл /var/lib/pgsql/14/data/pg_hba.conf добавляем разрешения для пользователя barman:
<pre>
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             192.168.57.0/24            scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             192.168.57.0/24            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
<b>host    all           barman       192.168.57.13/32        scram-sha-256</b>
<b>host    replication   barman       192.168.57.13/32      scram-sha-256</b>
</pre>

Перезапускаем службу postgresql-14: ```systemctl restart postgresql-14```<br />
В psql создадим тестовую базу otus: ```CREATE DATABASE otus;```<br />
В базе создаём таблицу test в базе otus: <br />
```
\c otus; 
CREATE TABLE test (id int, name varchar(30));
otus=# INSERT INTO test(id,name) VALUES(1, 'alex');
INSERT 0 1
otus=# SELECT * FROM test;
 id | name 
----+------
  1 | alex
(1 row)
```

#### На хосте barman:<br />
После генерации ключа, выводим содержимое файла ```~/.ssh/id_rsa.pub:```<br />
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4e18mhZgtGAMVZSlZINz/3tRUzJ4mg3AWAbHjiTha9I/Pfnnr3hW4z/bOtmevhlImPn7aUoCj/8bJXzB2zuLZsBCKdzSusNjNRJ+NS85NH+JhQJPZEkLHa99rOqOi35fKJa5xYDswYloWBluO+lz+nM0SshXfXbK3pmo7G1cS8Mce/+EiTLR/Q5VLQ7ktXJStGuetKfNwW2UKz05O9Vn8tgcPpvwH2Ze87/GoECmERNdrxwEoin8ldYNtCAbgpf2octyVqaz8cOB+roMOaP7IXdggaje+maRJBU19wwVSenQ9QYdrGX6sjzRqopGMNqmnQnL+c54r1OnhCoQcTd5tE4LGZiAtLqHq0Mbh4SBHzJyXkvDo6s7vHU0EktxfGm2oY27cftIjj9KKdRpV6t0KcVJKGYO8xOKcY9hWgzMhV9kb7Ywn3PKV/dyc+VB/CCBkBZ3gk4Zs0J8me6758GSXOTOp8ZuuwrKkblAj8PTtMSw+YCYNSPc7mAYEYHrX/sz5jGSO52iEnYm+4k4Me41SfqO26+lStbKpMH8B9kBi1aI2DKAcNovI4/Xx8PZ2HUeipxsSYnNaKxV7aDhI+eUfRaZbIGcfn1Rrdh02Rdhc/yK/COcgqBd6qT/uhOUYOKDP+FswS448IDChGvYAzUiFK1yvnFYhuUjA0iCn9Yh8Fw== barman@barman
```
Копируем содержимое файла на сервер postgres в файл ```/var/lib/pgsql/.ssh/authorized_keys```

Находясь в пользователе barman создаём файл ~/.pgpass со следующим содержимым:<br />
```
192.168.57.11:5432:*:barman:Otus2023
```
Установим права для файла по шаблону 0600.<br />

Проверяем возможность подключения к postgres-серверу:<br />
```
bash-4.4$ psql -h 192.168.57.11 -U barman -d postgres
WARNING: password file "/var/lib/barman/.pgpass" has group or world access; permissions should be u=rw (0600) or less
Password for user barman: 
psql (14.10)
Type "help" for help.

postgres=> \q
```
Проверяем репликацию:<br />
```
bash-4.4$ psql -h 192.168.57.11 -U barman -c "IDENTIFY_SYSTEM" replication=1
WARNING: password file "/var/lib/barman/.pgpass" has group or world access; permissions should be u=rw (0600) or less
Password for user barman: 
      systemid       | timeline |  xlogpos  | dbname 
---------------------+----------+-----------+--------
 7316957225590208201 |        1 | 0/30197E8 | 
(1 row)
```

Создаём файл ```/etc/barman.conf``` со следующим содержимым<br /> 
Владельцем файла должен быть пользователь barman:<br />
```
[barman]
barman_home = /var/lib/barman
configuration_files_directory = /etc/barman.d
barman_user = barman
log_file = /var/log/barman/barman.log
compression = gzip
backup_method = rsync
archiver = on
retention_policy = REDUNDANCY 3
immediate_checkpoint = true
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1
```
Создаём файл ```/etc/barman.d/node1.conf``` со следующим содержимым <br />
 Владельцем файла должен быть пользователь barman:<br />
```
[node1]
description = "backup node1"
ssh_command = ssh postgres@192.168.57.11 
conninfo = host=192.168.57.11 user=barman port=5432 dbname=postgres
retention_policy_mode = auto
retention_policy = RECOVERY WINDOW OF 7 days
wal_retention_policy = main
streaming_archiver=on
path_prefix = /usr/pgsql-14/bin/
create_slot = auto
slot_name = node1
streaming_conninfo = host=192.168.57.11 user=barman 
backup_method = postgres
archiver = off
```

Проверим работу barman:
```
bash-4.4$ barman switch-wal node1
EXCEPTION: Postgres user 'barman' is missing required privileges (see "Preliminary steps" in the Barman manual)
See log file for more details.
```
Поправим ошибку дав дополнительные разрешения для barman:
```
GRANT EXECUTE ON FUNCTION pg_start_backup(text, boolean, boolean) to barman;
GRANT EXECUTE ON FUNCTION pg_stop_backup() to barman;
GRANT EXECUTE ON FUNCTION pg_stop_backup(boolean, boolean) to barman;
GRANT EXECUTE ON FUNCTION pg_switch_wal() to barman;
GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) to barman;

GRANT pg_read_all_settings TO barman;
GRANT pg_read_all_stats TO barman;
```

Продолжим проверку:<br />
```
bash-4.4$ barman switch-wal node1
EXCEPTION: Postgres user 'barman' is missing required privileges (see "Preliminary steps" in the Barman manual)
See log file for more details.
bash-4.4$ barman switch-wal node1
The WAL file 000000010000000000000003 has been closed on server 'node1'
bash-4.4$ barman cron 
Starting WAL archiving for server node1
bash-4.4$ barman check node1
Server node1:
	PostgreSQL: OK
	superuser or standard user with backup privileges: OK
	PostgreSQL streaming: OK
	wal_level: OK
	replication slot: OK
	directories: OK
	retention policy settings: OK
	backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
	backup minimum size: OK (0 B)
	wal maximum age: OK (no last_wal_maximum_age provided)
	wal size: OK (0 B)
	compression settings: OK
	failed backups: OK (there are 0 failed backups)
	minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
	pg_basebackup: OK
	pg_basebackup compatible: OK
	pg_basebackup supports tablespaces mapping: OK
	systemid coherence: OK (no system Id stored on disk)
	pg_receivexlog: OK
	pg_receivexlog compatible: OK
	receive-wal running: OK
	archiver errors: OK
```

Запускаем резервное копирование:<br />
```
bash-4.4$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20231226T211347
Backup start at LSN: 0/4000060 (000000010000000000000004, 00000060)
Starting backup copy via pg_basebackup for 20231226T211347
Copy done (time: 7 seconds)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
	000000010000000000000003 from server node1 has been removed
Backup size: 41.9 MiB
Backup end at LSN: 0/6000000 (000000010000000000000005, 00000000)
Backup completed (start time: 2023-12-26 21:13:47.504914, elapsed time: 9 seconds)
Processing xlog segments from streaming for node1
	000000010000000000000004
	000000010000000000000005
```

Проверка восстановления из бекапов:<br />
На хосте node1 в psql удаляем базы Otus:<br />
```
postgres=# DROP DATABASE otus;
DROP DATABASE
postgres=# 
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 replica   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)
```

Далее на хосте barman запустим восстановление:<br />
<pre>
bash-4.4$ <b>barman list-backup node1</b>
node1 20231226T211347 - Tue Dec 26 21:14:17 2023 - Size: 41.9 MiB - WAL Size: 0 B
bash-4.4$ <b>barman recover node1 20231226T211347 /var/lib/pgsql/14/data/ --remote-ssh-command "ssh postgres@192.168.57.11"</b>
The authenticity of host '192.168.57.11 (192.168.57.11)' can't be established.
ECDSA key fingerprint is SHA256:4tHavyvJ8p2XGz+tkQU8IrWwgXOpeDktdAzff52mvmQ.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Starting remote restore for server node1 using backup 20231226T211347
Destination directory: /var/lib/pgsql/14/data/
Remote command: ssh postgres@192.168.57.11
Copying the base backup.
Copying required WAL segments.
Generating archive status files
Identify dangerous settings in destination directory.

Recovery completed (start time: 2023-12-26 21:30:31.862008+00:00, elapsed time: 16 seconds)
Your PostgreSQL server has been successfully prepared for recovery!
</pre>


Далее на хосте node1 потребуется перезапустить postgresql-сервер и снова проверить список БД.<br />
```
[root@node1 /]# systemctl restart postgresql-14
[root@node1 /]# su postgres
bash-4.4$ psql
psql (14.10)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 replica   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(5 rows)

postgres=# 
```