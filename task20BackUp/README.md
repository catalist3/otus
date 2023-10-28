#### Описание домашнего задания


1.Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client.<br />
2.Настроить удаленный бэкап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:<br />
3.Директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;<br />
4.Репозиторий для резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;<br />
5.Имя бэкапа должно содержать информацию о времени снятия бекапа;<br />
6.Глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;<br />
7.Резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;<br />
написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;<br />
8.Настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.<br />

#### Выполнение задания

Все комманды в задании будем выполнять с учетной записью root.<br />

Подключаем EPEL репозиторий на обоих ВМ:
```
[root@client ~]# yum repolist
................................
repo id                 repo name                                             status
base/7/x86_64           CentOS-7 - Base                                       10072
epel/x86_64             Extra Packages for Enterprise Linux 7 - x86_64        13790
extras/7/x86_64         CentOS-7 - Extras                                       518
updates/7/x86_64        CentOS-7 - Updates                                     5367
```
```
[root@backup ~]# yum repolist
.................................
repo id                          repo name                                                      status
base/7/x86_64                    CentOS-7 - Base                                                10072
epel/x86_64                      Extra Packages for Enterprise Linux 7 - x86_64                 13790
extras/7/x86_64                  CentOS-7 - Extras                                                518
updates/7/x86_64                 CentOS-7 - Updates                                              5367
```
Установим сервис бекапа borg:
```
[root@backup ~]# yum install -y borgbackup
.........................................
[root@backup ~]# whereis borg
borg: /usr/bin/borg /usr/share/man/man1/borg.1.gz
```
К ВМ backup подключим дополнительный диск объемом 2Gb.
```
[root@backup ~]# lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk 
`-sda1   8:1    0  40G  0 part /
sdb      8:16   0   2G  0 disk 
```
Создаем пользователя borg:
```
[root@backup ~]# useradd -m borg
[root@backup ~]# cat /etc/shadow
root:$1$m.FEVNiS$OYiaRNHMHzS85/wnDHccI.::0:99999:7:::
.....................................................
borg:!!:19658:0:99999:7:::
```

Cоздаем каталог /var/backup:
```
[root@backup /]# tree /var/backup
/var/backup

0 directories, 0 files
```
Создадим раздел на ранее подключенном диске:
```
[root@backup /]# parted /dev/sdb
GNU Parted 3.1
Using /dev/sdb
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) print                                                            
Error: /dev/sdb: unrecognised disk label
Model: ATA VBOX HARDDISK (scsi)                                           
Disk /dev/sdb: 2147MB
Sector size (logical/physical): 512B/512B
Partition Table: unknown
Disk Flags: 
(parted) mktable msdos                                                    
(parted) unit %
(parted) mkpart primary xfs 0 100%                                        
(parted) unit Mb                                                          
(parted) print                                                            
Model: ATA VBOX HARDDISK (scsi)
Disk /dev/sdb: 2147MB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type     File system  Flags
 1      1.05MB  2147MB  2146MB  primary

(parted) quit                                                             
Information: You may need to update /etc/fstab.
```
Проверим:
```
[root@backup /]# lsblk                                                    
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk 
`-sda1   8:1    0  40G  0 part /
sdb      8:16   0   2G  0 disk 
`-sdb1   8:17   0   2G  0 part 
```

Отформатируем /dev/sdb1 и смонтируем к /var/backup:
```
[root@backup /]# lsblk                                                    
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk 
`-sda1   8:1    0  40G  0 part /
sdb      8:16   0   2G  0 disk 
`-sdb1   8:17   0   2G  0 part 
[root@backup /]# mkfs.xfs /dev/sdb1
meta-data=/dev/sdb1              isize=512    agcount=4, agsize=131008 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=524032, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@backup /]# blkid -s UUID -o value /dev/sdb1
45cd03b8-037f-4c81-92de-fef56c13694b

[root@backup /]# mount --uuid="45cd03b8-037f-4c81-92de-fef56c13694b" /var/backup

[root@backup /]# lsblk -f
NAME   FSTYPE LABEL UUID                                 MOUNTPOINT
sda                                                      
`-sda1 xfs          1c419d6c-5064-4a2b-953c-05b2c67edb15 /
sdb                                                      
`-sdb1 xfs          45cd03b8-037f-4c81-92de-fef56c13694b /var/backup
```
Назначим права пользователя borg на директорию /var/backup:
```
[root@backup /]# chown borg:borg /var/backup
[root@backup /]# ls -la /var/backup
total 0
drwxr-xr-x.  2 borg borg   6 Oct 28 13:58 .
drwxr-xr-x. 19 root root 268 Oct 28 13:33 ..
[root@backup /]# ls -lda /var/backup
drwxr-xr-x. 2 borg borg 6 Oct 28 13:58 /var/backup
```
Создаем каталог ~/.ssh в домашнем каталоге пользователя borg в данном каталогу будут храниться ssh-ключи в файле authorized_keys<br />
```
[root@backup /]# cd /home/borg/
[root@backup borg]# su - borg
[borg@backup ~]$ mkdir .ssh
[borg@backup ~]$ touch .ssh/authorized_keys
[borg@backup ~]$ chmod 700 .ssh
[borg@backup ~]$ chmod 600 .ssh/authorized_keys
[borg@backup ~]$ ll
total 0
[borg@backup ~]$ pwd
/home/borg
[borg@backup ~]$ ls -la
total 12
drwx------. 3 borg borg  74 Oct 28 17:54 .
drwxr-xr-x. 4 root root  33 Oct 28 13:32 ..
-rw-r--r--. 1 borg borg  18 Apr  1  2020 .bash_logout
-rw-r--r--. 1 borg borg 193 Apr  1  2020 .bash_profile
-rw-r--r--. 1 borg borg 231 Apr  1  2020 .bashrc
drwx------. 2 borg borg  29 Oct 28 17:54 .ssh
[borg@backup ~]$ ls la .ssh/authorized_keys 
ls: cannot access la: No such file or directory
.ssh/authorized_keys
[borg@backup ~]$ ls -la .ssh/authorized_keys 
-rw-------. 1 borg borg 0 Oct 28 17:54 .ssh/authorized_keys
```
Далее идем на client, сгенерируем пару ключей, нам будет интересен в первую очередь публичный ключ:
```
[root@client ~]# cat ~/.ssh/id_rsa.pub 
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD/LqMRs3os5szL4XsBnXbb59/6avQEEl/LtDzD4pwn1tt5axs154/j7OHlMerIneKSXVYd639tUa2qlkOz0P31RaUzUfzZfe/RuLtS5aXljq9/QybnW2rCXWCxzfAjd2BZU99yBrv5wxOyrvkpz7/RWdAAXkjyoqGZTzEzHE/FzALuKYqhfD6XfpAsqi3T+GLvAMgAyQkUtf4J7lYxcBF2FiW5dKPxVQG4CAj7xjROXvSa2aviLqAGxURPCd1oicy8exyuWIbQjhpn+ksl9WY19E00PmdMD18n/pEy1Re/Yh7iGnd+HM3inJMVy6XJaw6s6jPGmbMG9QdzTN9yyAAV root@client.local
```
Содержимое публичного надо будет скопировать на сервер backup в ранее созданный файл authorized_keys.
Проверим возможность подключения:<br />
```
[root@client ~]# cat ~/.ssh/id_rsa.pub 
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD/LqMRs3os5szL4XsBnXbb59/6avQEEl/LtDzD4pwn1tt5axs154/j7OHlMerIneKSXVYd639tUa2qlkOz0P31RaUzUfzZfe/RuLtS5aXljq9/QybnW2rCXWCxzfAjd2BZU99yBrv5wxOyrvkpz7/RWdAAXkjyoqGZTzEzHE/FzALuKYqhfD6XfpAsqi3T+GLvAMgAyQkUtf4J7lYxcBF2FiW5dKPxVQG4CAj7xjROXvSa2aviLqAGxURPCd1oicy8exyuWIbQjhpn+ksl9WY19E00PmdMD18n/pEy1Re/Yh7iGnd+HM3inJMVy6XJaw6s6jPGmbMG9QdzTN9yyAAV root@client.local
[root@client ~]# ssh borg@192.168.11.160
The authenticity of host '192.168.11.160 (192.168.11.160)' can't be established.
ECDSA key fingerprint is SHA256:jb3ujc+bPmCf90fI/sfhXjRjJKJ2Ba5wad5ntkQSlwQ.
ECDSA key fingerprint is MD5:cb:23:f5:fe:98:5d:f4:3b:86:b5:01:95:c4:a0:52:44.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.11.160' (ECDSA) to the list of known hosts.
Last login: Sat Oct 28 17:53:58 2023
[borg@backup ~]$ 
```
Инициализируем репозиторий borg на backup сервере с client сервера:<br />
```
[root@client ~]# borg init --encryption=repokey borg@192.168.11.160:/var/backup/
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]: y
Your passphrase (between double-quotes): "Otus"
Make sure the passphrase displayed above is exactly what you wanted.

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://borg@192.168.11.160/var/backup

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
If you used a repokey mode, the key is stored in the repo, but you should back it up separately.
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```
Проверим возможность создания бэкапа:
```
borg create --stats --list borg@192.168.11.160:/var/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
```
```
Archive name: etc-2023-10-26_03:41:29
Archive fingerprint: 72bda5f2c2ecff2875ee9d2e61a2188a32ba8422e136b9702689a48c1fafb847
Time (start): Thu, 2023-10-26 03:41:40
Time (end):   Thu, 2023-10-26 03:41:51
Duration: 10.77 seconds
Number of files: 1698
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               28.43 MB             13.49 MB             11.84 MB
All archives:               28.43 MB             13.49 MB             11.84 MB

                       Unique chunks         Total chunks
Chunk index:                    1278                 1694
```
Взглянем на список файлов в бекапе:
```
[root@client ~]# borg list borg@192.168.11.160:/var/backup/::etc-2023-10-26_03:41:29 | head -n 10
Enter passphrase for key ssh://borg@192.168.11.160/var/backup: 
drwxr-xr-x root   root          0 Wed, 2023-10-25 21:08:17 etc
-rw------- root   root          0 Thu, 2020-04-30 22:04:55 etc/crypttab
lrwxrwxrwx root   root         17 Thu, 2020-04-30 22:04:55 etc/mtab -> /proc/self/mounts
-rw-r--r-- root   root      12288 Wed, 2023-10-25 20:01:59 etc/aliases.db
-rw-r--r-- root   root       2388 Thu, 2020-04-30 22:08:36 etc/libuser.conf
-rw-r--r-- root   root       2043 Thu, 2020-04-30 22:08:36 etc/login.defs
-rw-r--r-- root   root         37 Thu, 2020-04-30 22:08:36 etc/vconsole.conf
lrwxrwxrwx root   root         25 Thu, 2020-04-30 22:08:36 etc/localtime -> ../usr/share/zoneinfo/UTC
-rw-r--r-- root   root         19 Thu, 2020-04-30 22:08:36 etc/locale.conf
-rw-r--r-- root   root         13 Wed, 2023-10-25 20:02:12 etc/hostname
```
Извлечем файл из бекапа:
```
[root@client ~]# borg extract borg@192.168.11.160:/var/backup/::etc-2023-10-26_03:41:29 etc/locale.conf
Enter passphrase for key ssh://borg@192.168.11.160/var/backup:
..............................................................
[root@client ~]# ls -la etc/
total 4
drwx------. 2 root root  25 Oct 26 03:53 .
dr-xr-x---. 7 root root 201 Oct 26 03:53 ..
-rw-r--r--. 1 root root  19 Apr 30  2020 locale.conf
```

Автоматизируем создание бэкапов с помощью systemd.Создаем сервис и таймер в каталоге /etc/systemd/system/

```
vi /etc/systemd/system/borg-backup.service
```

```
[Unit]
Description=Borg Backup

[Service]
Type=oneshot

# Passphrase
Environment=BORG_PASSPHRASE=Otus

# Repository
Environment=REPO=borg@192.168.11.160:/var/backup/

# Object for backuping
Environment=BACKUP_TARGET=/etc


# Create backup
ExecStart=/bin/borg create \
--stats \
${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}


# Check backup
ExecStart=/bin/borg check ${REPO}


# Clear old backup
ExecStart=/bin/borg prune \
--keep-daily 90 \
--keep-monthly 12 \
--keep-yearly 1 \
${REPO}
```

```
vi /etc/systemd/system/borg-backup.timer
```
```
# /etc/systemd/system/borg-backup.timer

[Unit]
Description=Borg Backup
Requires=borg-backup.service

[Timer]
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```
Перезапустим демон systemd, перезапустим таймер и проверим его статус:
```
[root@client ~]# systemctl daemon-reload
[root@client ~]# systemctl restart borg-backup.timer
[root@client ~]# systemctl list-timers --all
NEXT                         LEFT          LAST                         PASSED UNIT                         ACTIVATES
Thu 2023-10-26 04:46:41 UTC  4min 54s left n/a                          n/a    borg-backup.timer            borg-backup.service
Thu 2023-10-26 20:16:22 UTC  15h left      Wed 2023-10-25 20:16:22 UTC  8h ago systemd-tmpfiles-clean.timer systemd-tmpfiles-clean
n/a                          n/a           n/a                          n/a    systemd-readahead-done.timer systemd-readahead-done
```
Проверим работу бекапа:
```
Enter passphrase for key ssh://borg@192.168.11.160/var/backup: 
etc-2023-10-26_06:30:23              Thu, 2023-10-26 06:30:28 [716cfe06280b2fb669d2583e118dc87934e28f79f8a40ba6350a0a5db5bfdd44]
etc-2023-10-26_06:31:55              Thu, 2023-10-26 06:32:00 [8d1cb3c889f9e3c0610087a455f183482abaae700887e7e5e013115732e3d954]
etc-2023-10-26_06:37:23              Thu, 2023-10-26 06:37:28 [8c7f16ed6e9cc2c60c9131c4580b7db53a03a583ff2a83e982c3cf93049cc757]
```
Настроим логирование событий borg в отдельный файл /var/log/borg-backup.log.<br />
Добавим в файл etc/systemd/system/borg-backup.service следующие строки:
```
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=borg-backup
```
Добавим в /etc/rsyslog.d/ файл конфигурации borg-backup.conf с указанием куда перенаправлять файл.
```
[root@client ~]# cat /etc/rsyslog.d/borg-backup.conf
if $programname == 'borg-backup' then /var/log/borg-backup.log
& stop
```
Настроим ротацию логов:
```
vi /etc/logrotate.d/borg-backup.conf
```

```
/var/log/borg-backup.log {
  rotate 3
  missingok
  notifempty
  compress
  size 1M
  daily
  create 0644 root root
}
```
Перезапустим rsyslog и демон systemd и проверим работу логирования:

```
[root@client ~]# cat /var/log/borg-backup.log
Oct 26 06:58:54 client borg-backup: ------------------------------------------------------------------------------
Oct 26 06:58:54 client borg-backup: Archive name: etc-2023-10-26_06:58:48
Oct 26 06:58:54 client borg-backup: Archive fingerprint: 15c8fc83d0ceb857c90b7b2bd44155f26b0bad32a4e433aae9d1cc0b2b76e18b
Oct 26 06:58:54 client borg-backup: Time (start): Thu, 2023-10-26 06:58:52
Oct 26 06:58:54 client borg-backup: Time (end):   Thu, 2023-10-26 06:58:54
Oct 26 06:58:54 client borg-backup: Duration: 1.62 seconds
Oct 26 06:58:54 client borg-backup: Number of files: 1702
Oct 26 06:58:54 client borg-backup: Utilization of max. archive size: 0%
Oct 26 06:58:54 client borg-backup: ------------------------------------------------------------------------------
Oct 26 06:58:54 client borg-backup: Original size      Compressed size    Deduplicated size
Oct 26 06:58:54 client borg-backup: This archive:               28.43 MB             13.49 MB             42.27 kB
Oct 26 06:58:54 client borg-backup: All archives:              170.57 MB             80.96 MB             11.95 MB
Oct 26 06:58:54 client borg-backup: Unique chunks         Total chunks
Oct 26 06:58:54 client borg-backup: Chunk index:                    1293                10180
Oct 26 06:58:54 client borg-backup: ------------------------------------------------------------------------------
Oct 26 06:59:42 client borg-backup: ------------------------------------------------------------------------------
Oct 26 06:59:42 client borg-backup: Archive name: etc-2023-10-26_06:59:34
Oct 26 06:59:42 client borg-backup: Archive fingerprint: 518eba862f274ae86cb684ae15733c32f19cc60a30ec0f3068224d9a9af99ce8
Oct 26 06:59:42 client borg-backup: Time (start): Thu, 2023-10-26 06:59:38
Oct 26 06:59:42 client borg-backup: Time (end):   Thu, 2023-10-26 06:59:41
Oct 26 06:59:42 client borg-backup: Duration: 2.54 seconds
Oct 26 06:59:42 client borg-backup: Number of files: 1702
Oct 26 06:59:42 client borg-backup: Utilization of max. archive size: 0%
Oct 26 06:59:42 client borg-backup: ------------------------------------------------------------------------------
Oct 26 06:59:42 client borg-backup: Original size      Compressed size    Deduplicated size
Oct 26 06:59:42 client borg-backup: This archive:               28.43 MB             13.49 MB                619 B
Oct 26 06:59:42 client borg-backup: All archives:              170.57 MB             80.96 MB             11.95 MB
Oct 26 06:59:42 client borg-backup: Unique chunks         Total chunks
Oct 26 06:59:42 client borg-backup: Chunk index:                    1293                10182
Oct 26 06:59:42 client borg-backup: ------------------------------------------------------------------------------
Oct 26 07:05:30 client borg-backup: ------------------------------------------------------------------------------
Oct 26 07:05:30 client borg-backup: Archive name: etc-2023-10-26_07:05:24
Oct 26 07:05:30 client borg-backup: Archive fingerprint: 4b7e67425bcf64b1f8be6e96cb31aff9b59b7aacf08066fc7347f1284f66ec6e
Oct 26 07:05:30 client borg-backup: Time (start): Thu, 2023-10-26 07:05:28
Oct 26 07:05:30 client borg-backup: Time (end):   Thu, 2023-10-26 07:05:30
Oct 26 07:05:30 client borg-backup: Duration: 1.71 seconds
Oct 26 07:05:30 client borg-backup: Number of files: 1702
Oct 26 07:05:30 client borg-backup: Utilization of max. archive size: 0%
Oct 26 07:05:30 client borg-backup: ------------------------------------------------------------------------------
Oct 26 07:05:30 client borg-backup: Original size      Compressed size    Deduplicated size
Oct 26 07:05:30 client borg-backup: This archive:               28.43 MB             13.49 MB                619 B
Oct 26 07:05:30 client borg-backup: All archives:              170.57 MB             80.96 MB             11.95 MB
Oct 26 07:05:30 client borg-backup: Unique chunks         Total chunks
Oct 26 07:05:30 client borg-backup: Chunk index:                    1293                10184
```





