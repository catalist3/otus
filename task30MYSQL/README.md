#### Описание домашнего задания
В материалах приложены ссылки на вагрант для репликации и дамп базы bet.dmp<br />
Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:<br />
| bookmaker   |
| competition  |
| market         |
| odds            |
| outcome      |

Настроить GTID репликацию<br />
варианты которые принимаются к сдаче:<br />
рабочий вагрантафайл<br />
скрины или логи SHOW TABLES<br />
конфиги<br />

#### Настройка Master

#### Установка mysql<br />
```
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y

yum install Percona-Server-server-57 -y
```

Копируем конфиги из /vagrant/conf.d в /etc/my.cnf.d/<br />
```cp /vagrant/conf/conf.d/* /etc/my.cnf.d/```

```
[root@master ~]# ls -l /etc/my.cnf.d/
total 20
-rw-------. 1 root root 207 Dec 15 13:54 01-base.cnf
-rw-------. 1 root root  48 Dec 15 13:54 02-max-connections.cnf
-rw-------. 1 root root 487 Dec 15 13:54 03-performance.cnf
-rw-------. 1 root root  66 Dec 15 13:54 04-slow-query.cnf
-rw-------. 1 root root 385 Dec 15 13:54 05-binlog.cnf
```
#### Запускаем сервис mysql:<br />
```
systemctl start mysql
[root@master ~]# systemctl status mysql
● mysqld.service - MySQL Server
   Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-12-15 13:56:44 UTC; 1h 57min ago
     Docs: man:mysqld(8)
           http://dev.mysql.com/doc/refman/en/using-systemd.html
  Process: 3809 ExecStart=/usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid $MYSQLD_OPTS (code=exited, status=0/SUCCESS)
  Process: 3752 ExecStartPre=/usr/bin/mysqld_pre_systemd (code=exited, status=0/SUCCESS)
 Main PID: 3812 (mysqld)
   CGroup: /system.slice/mysqld.service
           └─3812 /usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid

Dec 15 13:56:34 master systemd[1]: Starting MySQL Server...
Dec 15 13:56:44 master systemd[1]: Started MySQL Server.
```
Находим временный пароль для пользователя root:<br />
```
[root@master ~]# cat /var/log/mysqld.log | grep 'root@localhost:'
2023-12-15T13:56:38.211435Z 1 [Note] A temporary password is generated for root@localhost: WHuO9j8en3))
[root@master ~]# cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
```WHuO9j8en3))```
```
Подключимся к mysql и сменим пароль для root:
```
[root@master ~]# mysql -uroot -p'WHuO9j8en3))'
mysql> ALTER USER USER() IDENTIFIED BY'Otus@333';
```
Репликацию будем настраивать с использованием GTID.<br />
Смотрим атрибут server_id:<br />
```
mysql> SELECT @@server_id;
+-------------+
| @@server_id |
+-------------+
|           0 |
+-------------+
1 row in set (0.00 sec)

mysql> SHOW VARIABLES LIKE 'gtid_mode';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| gtid_mode     | OFF   |
+---------------+-------+
1 row in set (0.00 sec)
```
Видно нестыковку gtid_mode выключен и server_id 0 а не 1 как указано в настройках конфиг-файлов в папке /etc/my.cnf.d/. Всё потому, что на файлы надо было выставить права на чтение, в моем случае при копирровании они были только у пользователя root.<br />
Таким образом мне пришлось прибегнуть к ручному конфигурированию этих настроек, хотя по сути их можно поправить в любой момент и перезапустить mysql. Ну ничего, потренировался зато.
```
mysql> SET @@GLOBAL.GTID_MODE = ON;
ERROR 1788 (HY000): The value of @@GLOBAL.GTID_MODE can only be changed one step at a time: OFF <-> OFF_PERMISSIVE <-> ON_PERMISSIVE <-> ON. Also note that this value must be stepped up or down simultaneously on all servers. See the Manual for instructions.
mysql> SET @@GLOBAL.GTID_MODE = OFF_PERMISSIVE;
Query OK, 0 rows affected (0.00 sec)

mysql> SET @@GLOBAL.GTID_MODE = ON_PERMISSIVE;
Query OK, 0 rows affected (0.00 sec)

mysql> SET @@GLOBAL.GTID_MODE = ON;
ERROR 3111 (HY000): SET @@GLOBAL.GTID_MODE = ON is not allowed because ENFORCE_GTID_CONSISTENCY is not ON.
mysql> SET @@GLOBAL.ENFORCE_GTID_CONSISTENCY = ON;
Query OK, 0 rows affected (0.00 sec)

mysql> SET @@GLOBAL.GTID_MODE = ON;
Query OK, 0 rows affected (0.00 sec)
```

```
mysql> SHOW VARIABLES LIKE 'gtid_mode';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| gtid_mode     | ON    |
+---------------+-------+
1 row in set (0.00 sec)
```



#### Создадим тестовую базу bet и загрузим в нее дамп и проверим:
```
mysql> CREATE DATABASE bet;
Query OK, 1 row affected (0.00 sec)
[root@otuslinux ~] mysql -uroot -p -D bet < /vagrant/bet.dmp
[root@master ~]# mysql -uroot -p'Otus@333'


mysql> USE bet
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> SHOW TABLES
    -> ;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)
```

#### Создадим пользователя для репликации и даем ему права на эту самую репликацию:
```
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT user,host FROM mysql.user where user='repl';
+------+------+
| user | host |
+------+------+
| repl | %    |
+------+------+
1 row in set (0.00 sec)

mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
Query OK, 0 rows affected, 1 warning (0.00 sec)
```

Дампим базу для последующего залива на slave и игнорируем таблицý по заданию:
```
mysqldump --all-databases --triggers --routines --master-data --ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -uroot -p > master.sql
```


#### Настройка Slave

Установка mysql полностью аналогична описанному для master процессу. За исключением изменения значения ```server-id``` в файле ```/etc/my.cnf.d/01-base.cnf```

<pre>
[root@replica ~]# vi /etc/my.cnf.d/01-base.cnf
[mysqld]
pid-file=/var/run/mysqld/mysqld.pid
log-error=/var/log/mysqld.log
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
symbolic-links=0

<b>server-id = 2</b>
innodb_file_per_table = 1
skip-name-resolve
</pre>

И двух раскомментированных строк в ```/etc/my.cnf.d/05-binlog.cnf```
<pre>
[mysqld]
log-bin = mysql-bin
expire-logs-days = 7
max-binlog-size = 16M
binlog-format = "MIXED"

# GTID replication config
log-slave-updates = On
gtid-mode = On
enforce-gtid-consistency = On

# Эта часть только для слэйва - исключаем репликацию таблиц
<b>replicate-ignore-table=bet.events_on_demand</b>
<b>replicate-ignore-table=bet.v_same_event</b>
</pre>

Запускаем сервис mysql:
```
[root@slave ~]# systemctl start mysql
```

Находим временный пароль для пользователя root:
```
[root@slave ~]# cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
tvh&UMA7BBl&
```

Подключаемся к mysql:
```
[root@slave ~]# mysql -uroot -p'tvh&UMA7BBl&'
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.44-48

Copyright (c) 2009-2023 Percona LLC and/or its affiliates
Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
```

и меняем пароль для доступа пользователя root:
```
mysql> ALTER USER USER() IDENTIFIED BY'Otus@333';
Query OK, 0 rows affected (0.00 sec)
```

Смотрим атрибут server_id:
```
mysql> SELECT @@server_id;
+-------------+
| @@server_id |
+-------------+
|           2 |
+-------------+
1 row in set (0.00 sec)
```

Перед попыткой залить дамп БД bet необходимо скопировать дамп с master:
```
scp -i ./.vagrant/machines/master/virtualbox/private_key root@192.168.11.150:/root/master.sql .
```
И на slave:
```
scp -i ./.vagrant/machines/slave/virtualbox/private_key ./master.sql root@192.168.11.151:/root/master.sql
```

Заливаем дамп master.sql:<br />
```
mysql> SOURCE /root/master.sql;
```

Убеждаемся что база есть:<br />
```
mysql> SHOW DATABASES LIKE 'bet';
+----------------+
| Database (bet) |
+----------------+
| bet            |
+----------------+
1 row in set (0.00 sec)

mysql> SHOW TABLES;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
5 rows in set (0.00 sec)
```
Подключаем и запускаем слейв:<br />
```
mysql> CHANGE MASTER TO MASTER_HOST = "192.168.11.150", MASTER_PORT = 3306, MASTER_USER = "repl", MASTER_PASSWORD = "!OtusLinux2018", MASTER_AUTO_POSITION = 1;
Query OK, 0 rows affected, 2 warnings (0.03 sec)

mysql> START SLAVE;
Query OK, 0 rows affected (0.01 sec)

mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.11.150
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000002
          Read_Master_Log_Pos: 450
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 663
        Relay_Master_Log_File: mysql-bin.000002
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
      Replicate_Wild_Do_Table: 

...............................................................................
```
Можно тут же глянуть на возможно имеющиеся ошибки:
```
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
```

Проверим репликацию в действии. На мастере:

```
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
Query OK, 1 row affected (0.01 sec)

mysql> SHOW TABLES;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)

mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

На слейве:

```
mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```