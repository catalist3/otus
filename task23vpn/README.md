#### Описание домашнего задания
1. Между двумя виртуалками поднять vpn в режимах:<br />
- tun
- tap
Описать в чём разница, замерить скорость между виртуальными машинами в туннелях, сделать вывод об отличающихся показателях скорости.<br />
2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку.

Вместо "бокса" centos/stream8 будем использовать "бокс" centos/8, поскольку указанный в методичке дистрибутив ни в какую не желает скачиваться. Для корректной работы centos/8 придется переконфигурировать репозиторий на зеркала на vault.centos.org:
```
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
```
После можно будет спокойно обновлять репозитории и подключить epel-release

#### 1. TUN/TAP режимы VPN

Следующие шаги одинаковы как для сервера так и для клиента:<br />
- устанавливаем epel репозиторий:
```
yum install -y epel-release
```
- устанавливаем пакет openvpn и iperf3
```
yum install -y openvpn iperf3
```
- Отключаем SELinux (помним, что данная настройка непостоянна и дествует до перезагрузки)
setenforce 0

Слеующие настройки осуществляются только на сервере:<br />
- создаём файл-ключ
```
openvpn --genkey --secret /etc/openvpn/static.key
```
- создаём конфигурационный файл vpn-сервера
```
vi /etc/openvpn/server.conf
```
со следующим содержимым:<br />
```
dev tap
ifconfig 10.10.10.1 255.255.255.0
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```
Создадим service unit для запуска openvpn:
```
vi /etc/systemd/system/openvpn@.service
```
```
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target
```
Запускаем openvpn сервер и добавляем в автозагрузку.
```
systemctl start openvpn@server
systemctl enable openvpn@server
```

#### Теперь идем на клиент:

Создаём конфигурационный файл клиента:
```
vi /etc/openvpn/client.conf
```
Файл будет содержать следующий конфиг:
```
dev tap
remote 192.168.56.10
ifconfig 10.10.10.2 255.255.255.0
topology subnet
route 192.168.56.0 255.255.255.0
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```
На ВМ client в директорию /etc/openvpn/ скопируем файл-ключ static.key, который был создан на сервере.<br />
На этом шаге можно воспользоваться scp и заодно вспомнить некоторые вещи касаемые настройки ssh(генерация и обмен ключей)<br />

Создадим service unit аналогичный созданному ранее на сервере и запустим его:<br />
```
systemctl start openvpn@client
```
Далее замерим скорость в туннеле.<br />
- на ВМ server (openvpn-сервер) запускаем iperf3 в режиме сервера:<br />
```
iperf3 -s &
```
на ВМ client (openvpn-клиент) запускаем iperf3 в режиме клиента и замеряем скорость в туннеле:
```
iperf3 -c 10.10.10.1 -t 40 -i 5
```
Вывод на клиенте:<br />
```
[root@client openvpn]# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 56332 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.01   sec  8.95 MBytes  15.0 Mbits/sec    4    102 KBytes       
^C[  5]   5.01-6.87   sec  3.16 MBytes  14.2 Mbits/sec    2   94.2 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-6.87   sec  12.1 MBytes  14.8 Mbits/sec    6             sender
[  5]   0.00-6.87   sec  0.00 Bytes  0.00 bits/sec                  receiver
iperf3: interrupt - the client has terminated
```
Вывод на сервере:<br />
```
[root@server openvpn]# iperf3 -s &
[1] 34099
[root@server openvpn]# -----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 10.10.10.2, port 56330
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 56332
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  1.46 MBytes  12.3 Mbits/sec                  
[  5]   1.00-2.00   sec  1.56 MBytes  13.1 Mbits/sec                  
[  5]   2.00-3.00   sec  1.78 MBytes  15.0 Mbits/sec                  
[  5]   3.00-4.00   sec  1.67 MBytes  14.0 Mbits/sec                  
[  5]   4.00-5.00   sec  1.75 MBytes  14.7 Mbits/sec                  
```

Изменим режим работы туннеля, скорректировав настройки на сервере и клиенте. Для этого необходимо изменить параметр dev на значение tun, и после перезапустить сервисы.
```
systemctl restart openvpn@client
systemctl restart openvpn@server
```
Запустим iperf и проверим результат:<br />
Вывод с клента:<br />
```
[root@client openvpn]# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 56336 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.01   sec  9.00 MBytes  15.1 Mbits/sec   11    108 KBytes       
[  5]   5.01-10.02  sec  9.39 MBytes  15.7 Mbits/sec    3    104 KBytes       
[  5]  10.02-15.01  sec  10.5 MBytes  17.7 Mbits/sec    2    106 KBytes       
[  5]  15.01-20.01  sec  9.63 MBytes  16.1 Mbits/sec    2   99.1 KBytes       
[  5]  20.01-25.01  sec  8.76 MBytes  14.7 Mbits/sec    3   95.1 KBytes       
^C[  5]  25.01-29.46  sec  8.24 MBytes  15.5 Mbits/sec    1    112 KBytes       
```

Вывод с сервера:
```
[root@server openvpn]# iperf3 -s &
[1] 34156
[root@server openvpn]# -----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 10.10.10.2, port 56334
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 56336
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  1.58 MBytes  13.2 Mbits/sec                  
[  5]   1.00-2.00   sec  1.66 MBytes  13.9 Mbits/sec                  
[  5]   2.00-3.00   sec  1.84 MBytes  15.5 Mbits/sec                  
[  5]   3.00-4.00   sec  1.63 MBytes  13.7 Mbits/sec                  
[  5]   4.00-5.00   sec  1.88 MBytes  15.7 Mbits/sec                  
[  5]   5.00-6.00   sec  1.90 MBytes  15.9 Mbits/sec                  
[  5]   6.00-7.00   sec  2.00 MBytes  16.8 Mbits/sec                  
[  5]   7.00-8.00   sec  1.84 MBytes  15.4 Mbits/sec                  
[  5]   8.00-9.00   sec  1.69 MBytes  14.2 Mbits/sec                  
[  5]   9.00-10.00  sec  1.95 MBytes  16.3 Mbits/sec                  
[  5]  10.00-11.00  sec  1.98 MBytes  16.6 Mbits/sec                  
[  5]  11.00-12.00  sec  1.92 MBytes  16.1 Mbits/sec                  
[  5]  12.00-13.00  sec  2.15 MBytes  18.1 Mbits/sec                  
[  5]  13.00-14.00  sec  2.09 MBytes  17.5 Mbits/sec                  
[  5]  14.00-15.00  sec  2.27 MBytes  19.1 Mbits/sec                  
....................................................
```

Разница tun и tap режимов:

TAP:

Преимущества:
- ведёт себя как настоящий сетевой адаптер (за исключением того, что он виртуальный);
- может осуществлять транспорт любого сетевого протокола (IPv4, IPv6, IPX и прочих);
- работает на 2 уровне, поэтому может передавать Ethernet-кадры внутри тоннеля;
- позволяет использовать мосты.

Недостатки:
- в тоннель попадает broadcast-трафик, что иногда не требуется;
- добавляет свои заголовки поверх заголовков Ethernet на все пакеты, которые следуют через тоннель;
- в целом, менее масштабируем из-за предыдущих двух пунктов;
- не поддерживается устройствами Android и iOS.

TUN:

Преимущества:
- передает только пакеты протокола IP (3й уровень);
- сравнительно (отн. TAP) меньшие накладные расходы и, фактически, ходит только тот IP-трафик, который предназначен конкретному клиенту.

Недостатки:
- broadcast-трафик обычно не передаётся;
- нельзя использовать мосты.


#### RAS на базе OpenVPN

Для выполнения данного задания можно воспользоваться Vagrantfile из 1 задания, только убрать 1 ВМ. Настроим конфигурацию репозитория аналогично тому что делали на ВМ из первой части и отключим selinux.


- Устанавливаем репозиторий EPEL:<br />
```
yum install -y epel-release
```
- Устанавливаем необходимые пакеты:<br />
```
yum install -y openvpn easy-rsa
```
- Переходим в директорию /etc/openvpn/ и инициализируем pki:<br />
```
cd /etc/openvpn/
/usr/share/easy-rsa/3.0.8/easyrsa init-pki
```
На всякий случай можно проверить установленную версию OpenVpn:<br />
```
[root@server openvpn]# rpm -qa | grep easy-rsa
easy-rsa-3.0.8-1.el8.noarch
```

Сгенерируем необходимые ключи и сертификаты для сервера.<br />
Получаем ключевую пару:
```
[root@server openvpn]# echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa build-ca nopass
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021
Generating RSA private key, 2048 bit long modulus (2 primes)
................................................................................................+++++
..........................+++++
e is 65537 (0x010001)
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]:
CA creation complete and you may now import and sign cert requests.
Your new CA certificate file for publishing is at:
/etc/openvpn/pki/ca.crt
```

Генерируем запрос.
```
[root@server openvpn]# echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa gen-req server nopass
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021
Generating a RSA private key
.................................+++++
.................................................................+++++
writing new private key to '/etc/openvpn/pki/easy-rsa-33617.FApiBg/tmp.kXQn7K'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [server]:
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/pki/reqs/server.req
key: /etc/openvpn/pki/private/server.key
```
Подписываем сертификат.
```
[root@server openvpn]# echo 'yes' | /usr/share/easy-rsa/3.0.8/easyrsa sign-req server server
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021


You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a server certificate for 825 days:

subject=
    commonName                = rasvpn


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: Using configuration from /etc/openvpn/pki/easy-rsa-33645.xRIbmM/tmp.cZcHSF
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'rasvpn'
Certificate is to be certified until Feb 14 11:05:31 2026 GMT (825 days)

Write out database with 1 new entries
Data Base Updated

Certificate created at: /etc/openvpn/pki/issued/server.crt
```
Генерируем ключ Диффи-Хелмана для передачи чуствительной информации по небезопасным каналам.
```
[root@server openvpn]# /usr/share/easy-rsa/3.0.8/easyrsa gen-dh
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
..........................+..+...............................................................................
DH parameters of size 2048 created at /etc/openvpn/pki/dh.pem
```

Сгенерируем сертификаты для клиента.<br />

```
[root@server openvpn]# echo 'client' | /usr/share/easy-rsa/3/easyrsa gen-req client nopass
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021
Generating a RSA private key
................................................................................................+++++
................................................................+++++
writing new private key to '/etc/openvpn/pki/easy-rsa-33733.KRzGfU/tmp.QMuuDV'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [client]:
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/pki/reqs/client.req
key: /etc/openvpn/pki/private/client.key


[root@server openvpn]# echo 'yes' | /usr/share/easy-rsa/3/easyrsa sign-req client client
Using SSL: openssl OpenSSL 1.1.1k  FIPS 25 Mar 2021


You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a client certificate for 825 days:

subject=
    commonName                = client


Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: Using configuration from /etc/openvpn/pki/easy-rsa-33761.KZb7pX/tmp.75luTb
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'client'
Certificate is to be certified until Feb 14 11:25:21 2026 GMT (825 days)

Write out database with 1 new entries
Data Base Updated

Certificate created at: /etc/openvpn/pki/issued/client.crt
```

Создадим service unit для запуска openvpn:
```
vi /etc/systemd/system/openvpn@.service
```
```
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target
```

Создадим конфигурационный файл ```/etc/openvpn/server.conf```:<br />
```
[root@localhost ~]# cat /etc/openvpn/server.conf
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.10.10.0 255.255.255.0
push "10.10.10.0 255.255.255.0"
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir /etc/openvpn/client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```
Скопируем следующие файлы сертификатов и ключ для клиента на хост-машину.
```
/etc/openvpn/pki/ca.crt
/etc/openvpn/pki/issued/client.crt
/etc/openvpn/pki/private/client.key
```
Можно сделать с помощью scp через промежуточную директорию с изменением прав на файлики(chmod 644).<br />
Иначе ругается на права доступа.<br />
Файлы копируем в ту же директории, что и client.conf

Создадим конфигурационны файл клиента client.conf на хост-машине:<br />
```
root@dimon-otus:/etc/openvpn# cat client.conf 
dev tun
proto udp
remote 192.168.56.101 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
route 10.10.10.0 255.255.255.0
persist-key
persist-tun
comp-lzo
verb 3
```

Проверяем подключение к RAS с хостовой машины, запускаем:
```
openvpn --config client.conf
```
Тестируем:

root@dimon-otus:/etc/openvpn# ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=2.34 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.99 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=2.17 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=2.35 ms
^C
--- 10.10.10.1 ping statistics ---

```
[root@localhost ~]# ping 10.10.10.6
PING 10.10.10.6 (10.10.10.6) 56(84) bytes of data.
64 bytes from 10.10.10.6: icmp_seq=1 ttl=64 time=1.64 ms
64 bytes from 10.10.10.6: icmp_seq=2 ttl=64 time=1.98 ms
64 bytes from 10.10.10.6: icmp_seq=3 ttl=64 time=2.08 ms
^C
--- 10.10.10.6 ping statistics ---
```

Записи для туннлей в таблице маршрутизации:
```
root@dimon-otus:/etc/openvpn# ip r 
default via 172.18.11.1 dev ens160 proto static metric 100 
10.10.10.0/24 via 10.10.10.5 dev tun0 
```
```
[root@localhost ~]# ip r
default via 10.0.2.2 dev eth0 proto dhcp metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.10.10.0/24 via 10.10.10.2 dev tun0 
```