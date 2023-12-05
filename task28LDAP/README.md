
#### Цель домашнего задания
Научиться настраивать LDAP-сервер и подключать к нему LDAP-клиентов

Привыполнении ДЗ используется образ Centos/8.<br />
Для исправление ошибки с неподдерживаемыми репозиториями необходимо изменить список этих репозиториев:<br />
```
sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
```

#### 1) Установка FreeIPA сервера<br />
Подключимся к нему по SSH к ВМ ipa.otus.lan, команды будем выполнять из под пользователя root ```sudo -i```

Начнём настройку FreeIPA-сервера:<br /> 
- Установим часовой пояс: ```timedatectl set-timezone Europe/Moscow```<br />
- Установим утилиту chrony: ```yum install -y chrony```<br />
- Запустим chrony и добавим его в автозагрузку: ```systemctl enable chronyd —now```<br />
- Выключим Firewall: ```systemctl stop firewalld```<br />
- Отключим автозапуск Firewalld: ```systemctl disable firewalld```<br />
- Остановим Selinux: ```setenforce 0```<br />
- Поменяем в файле ```/etc/selinux/config```, параметр Selinux на ```disabled```<br />

Для дальнейшей настройки FreeIPA нам потребуется, чтобы DNS-сервер хранил запись о нашем LDAP-сервере. В рамках данной лабораторной работы мы не будем настраивать отдельный DNS-сервер и просто добавим запись в файл /etc/hosts
```
[root@ipa ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.1.1 ipa.otus.lan ipa
192.168.57.10 ipa.otus.lan ipa
```

Установим модуль DL1: ```yum install -y @idm:DL1```<br />
Установим FreeIPA-сервер: ```yum install -y ipa-server```<br />

Запустим скрипт установки: ```ipa-server-install```<br />
Далее, нам потребуется указать параметры нашего LDAP-сервера, после ввода каждого параметра нажимаем Enter, если нас устраивает параметр, указанный в квадратных скобках, то можно сразу нажимать Enter:

```
[root@ipa ~]# ipa-server-install

The log file for this installation can be found in /var/log/ipaserver-install.log
==============================================================================
This program will set up the IPA Server.
Version 4.9.6

This includes:
  * Configure a stand-alone CA (dogtag) for certificate management
  * Configure the NTP client (chronyd)
  * Create and configure an instance of Directory Server
  * Create and configure a Kerberos Key Distribution Center (KDC)
  * Configure Apache (httpd)
  * Configure SID generation
  * Configure the KDC to enable PKINIT

To accept the default shown in brackets, press the Enter key.

Do you want to configure integrated DNS (BIND)? [no]: no

Enter the fully qualified domain name of the computer
on which you're setting up server software. Using the form
<hostname>.<domainname>
Example: master.example.com.


Server host name [ipa.otus.lan]: 

The domain name has been determined based on the host name.

Please confirm the domain name [otus.lan]: 

The kerberos protocol requires a Realm name to be defined.
This is typically the domain name converted to uppercase.

Please provide a realm name [OTUS.LAN]: 
Certain directory server operations require an administrative user.
This user is referred to as the Directory Manager and has full access
to the Directory for system management tasks and will be added to the
instance of directory server created for IPA.
The password must be at least 8 characters long.

Directory Manager password: 
Password (confirm): 

The IPA server requires an administrative user, named 'admin'.
This user is a regular system account used for IPA server administration.

IPA admin password: 
Password (confirm): 

Invalid IP address 127.0.1.1 for ipa.otus.lan: cannot use loopback IP address 127.0.1.1
Trust is configured but no NetBIOS domain name found, setting it now.
Enter the NetBIOS name for the IPA domain.
Only up to 15 uppercase ASCII letters, digits and dashes are allowed.
Example: EXAMPLE.


NetBIOS domain name [OTUS]: 

Do you want to configure chrony with NTP server or pool address? [no]: no

The IPA Master Server will be configured with:
Hostname:       ipa.otus.lan
IP address(es): 192.168.57.10
Domain name:    otus.lan
Realm name:     OTUS.LAN

The CA will be configured with:
Subject DN:   CN=Certificate Authority,O=OTUS.LAN
Subject base: O=OTUS.LAN
Chaining:     self-signed

Continue to configure the system with these values? [no]: 
```

#### Результаты настройки IPA
```
Please add records in this file to your DNS system: /tmp/ipa.system.records.mgxv7q6w.db
==============================================================================
Setup complete

Next steps:
	1. You must make sure these network ports are open:
		TCP Ports:
		  * 80, 443: HTTP/HTTPS
		  * 389, 636: LDAP/LDAPS
		  * 88, 464: kerberos
		UDP Ports:
		  * 88, 464: kerberos
		  * 123: ntp

	2. You can now obtain a kerberos ticket using the command: 'kinit admin'
	   This ticket will allow you to use the IPA tools (e.g., ipa user-add)
	   and the web user interface.

Be sure to back up the CA certificates stored in /root/cacert.p12
These files are required to create replicas. The password for these
files is the Directory Manager password
The ipa-server-install command was successful
```
После успешной установки FreeIPA, проверим, что сервер Kerberos может выдать нам билет:<br />
```
[root@ipa ~]# kinit admin
Password for admin@OTUS.LAN: 
[root@ipa ~]# klist
Ticket cache: KCM:0
Default principal: admin@OTUS.LAN

Valid starting     Expires            Service principal
12/05/23 19:11:10  12/06/23 18:53:00  krbtgt/OTUS.LAN@OTUS.LAN
```

Мы можем зайти в Web-интерфейс нашего FreeIPA-сервера, для этого на нашей хостой машине нужно прописать следующую строку в файле Hosts:
192.168.57.10 ipa.otus.lan

![Alt text](https://github.com/catalist3/otus/blob/master/task28LDAP/web_ipa.png?raw=true)

И...
![Alt text](https://github.com/catalist3/otus/blob/master/task28LDAP/into_ipa.png?raw=true)

На этом установка и настройка FreeIPA-сервера завершена.

#### Создание и настройка клиентского модуля FreeIPA

Установим нужный часовой пояс (в данном случае Europe/Moscow):
```
[root@client1 ~]# timedatectl set-timezone Europe/Moscow
```
Отредактируем файл ```/etc/hosts```<br />
```
[root@client1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.1.1 client1.otus.lan client1
192.168.57.10 ipa.otus.lan ipa
192.168.57.11 client1.otus.lan client1
```
Отключим SELinux:<br />
```
[root@client1 ~]# setenforce 0
```
Отключим Firewalld:<br />
```
[root@client1 ~]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:firewalld(1)
```
Устанавливаем пакет для клиента FreeIPA:<br />
```
yum install ipa-client -y
```
Присоединим нашего клиента к домену FreeIPA:<br />
```
root@client1 ~]# echo -e "yes\nyes" | ipa-client-install --mkhomedir --domain=OTUS.LAN --server=ipa.otus.lan --no-ntp -p admin -w Db,hfnjh#13
This program will set up IPA client.
Version 4.9.6

Autodiscovery of servers for failover cannot work with this configuration.
If you proceed with the installation, services will be configured to always access the discovered server for all operations and will not fail over to other servers in case of failure.
Proceed with fixed values and no DNS discovery? [no]: Client hostname: client1.otus.lan
Realm: OTUS.LAN
DNS Domain: otus.lan
IPA Server: ipa.otus.lan
BaseDN: dc=otus,dc=lan

Continue to configure the system with these values? [no]: Skipping chrony configuration
Successfully retrieved CA cert
    Subject:     CN=Certificate Authority,O=OTUS.LAN
    Issuer:      CN=Certificate Authority,O=OTUS.LAN
    Valid From:  2023-12-05 15:57:19
    Valid Until: 2043-12-05 15:57:19

Enrolled in IPA realm OTUS.LAN
Created /etc/ipa/default.conf
Configured sudoers in /etc/authselect/user-nsswitch.conf
Configured /etc/sssd/sssd.conf
Configured /etc/krb5.conf for IPA realm OTUS.LAN
Systemwide CA database updated.
Hostname (client1.otus.lan) does not have A/AAAA record.
Failed to update DNS records.
Missing A/AAAA record(s) for host client1.otus.lan: 192.168.57.11.
Missing reverse record(s) for address(es): 192.168.57.11.
Adding SSH public key from /etc/ssh/ssh_host_ed25519_key.pub
Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub
Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub
Could not update DNS SSHFP records.
SSSD enabled
Configured /etc/openldap/ldap.conf
Configured /etc/ssh/ssh_config
Configured /etc/ssh/sshd_config
Configuring otus.lan as NIS domain.
Client configuration complete.
The ipa-client-install command was successful

```

На примере уже настроенного пользователя admin получим билет kerberos:<br />
```
[root@client1 ~]# kinit admin
Password for admin@OTUS.LAN: 
[root@client1 ~]# klist
Ticket cache: KCM:0
Default principal: admin@OTUS.LAN

Valid starting     Expires            Service principal
12/05/23 20:44:47  12/06/23 20:44:43  krbtgt/OTUS.LAN@OTUS.LAN
```

Давайте проверим работу LDAP, для этого на сервере FreeIPA создадим пользователя и попробуем залогиниться к клиенту.<br />
Пользователь в этом случае для разнообразия создал через веб-консоль:<br />
```
[root@client1 ~]# kinit ivanov
Password for ivanov@OTUS.LAN: 
Password expired.  You must change it now.
Enter new password: 
Enter it again: 
Password mismatch.  Please try again.
Enter new password: 
Enter it again: 
[root@client1 ~]# klist
Ticket cache: KCM:0:7389
Default principal: ivanov@OTUS.LAN

Valid starting     Expires            Service principal
12/05/23 20:48:08  12/06/23 19:53:26  krbtgt/OTUS.LAN@OTUS.LAN
```