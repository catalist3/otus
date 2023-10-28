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