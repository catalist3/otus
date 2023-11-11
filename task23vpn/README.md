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

Создадим service unit аналогичный созданному ранее на сервере и запусти его:<br />
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
Запусти iperf и проверим результат:<br />
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