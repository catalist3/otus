#### Описание домашнего задания
1. Развернуть 3 виртуальные машины<br />
2. Объединить их разными vlan<br />
- настроить OSPF между машинами на базе Quagga;<br />
- изобразить ассиметричный роутинг;<br />
- сделать один из линков "дорогим", но что бы при этом роутинг был симметричным.<br />

#### Схема сети тестового стенда

![Alt text](https://github.com/catalist3/otus/blob/master/task22routing/Schema_net.png?raw=true)

После включения ВМ для тестового стенда можем приступать непосредственно к настройке протокола маршрутизации.

#### Установка пакетов для тестирования и настройки OSPF

Перед настройкой FRR рекомендуется поставить базовые программы для изменения конфигурационных файлов (vim) и изучения сети (traceroute, tcpdump, net-tools):
```
apt update
apt install vim traceroute tcpdump net-tools
```

#### Настройка демона OSPF

Протокол OSPF на базе ОС Linux реализуется путем настройки пакета FRR который является наследником пакета Quagga<br />

1) Отключаем файерволл ufw и удаляем его из автозагрузки:<br />
```
   systemctl stop ufw 
   systemctl disable ufw
```
2) Добавляем gpg ключ:<br />
```
   curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
```
3) Добавляем репозиторий c пакетом FRR:<br />
```
   echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable > /etc/apt/sources.list.d/frr.list
```
4) Обновляем пакеты и устанавливаем FRR:<br />
```
apt update
apt install frr frr-pythontools
```
5) Разрешаем (включаем) маршрутизацию транзитных пакетов:<br />
```
sysctl net.ipv4.conf.all.forwarding=1
```
Не забываем, что для перманентного изменения возможности форвардинга ip-трафика необходимо внести изменения в файл ```/etc/sysctl.conf```

6) Включаем демон ospfd в FRR<br />
Для этого открываем в редакторе файл /etc/frr/daemons и меняем в нём параметры для пакетов ospfd на yes:<br />
Включать пакет zebra не нужно, согласно комментарию в конфиг-файле ```The watchfrr, zebra and staticd daemons are always started.``` он уже включен.

7) Настройка OSPF<br />
Для настройки OSPF нам потребуется создать файл /etc/frr/frr.conf который будет содержать в себе информацию о требуемых интерфейсах и OSPF.<br /> 
Разберем пример создания файла на хосте router1.<br />

Для начала нам необходимо узнать имена интерфейсов и их адреса. Сделать это можно с помощью двух способов:
Посмотреть в linux: ```ip a | grep inet```
```
root@router1:~# ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
    inet 10.0.10.1/30 brd 10.0.10.3 scope global eth1
    inet 10.0.12.1/30 brd 10.0.12.3 scope global eth2
    inet 192.168.10.1/24 brd 192.168.10.255 scope global eth3
    inet 192.168.50.10/24 brd 192.168.50.255 scope global eth4
```

Либо через интерфейс FRR:<br />
Синтаксис очень схож с синтаксисом команд сетевых устройств Cisco<br />
```
root@router1:~# vtysh

Hello, this is FRRouting (version 9.0.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# show interface brief
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
eth0            up      default         10.0.2.15/24
eth1            up      default         10.0.10.1/30
eth2            up      default         10.0.12.1/30
eth3            up      default         192.168.10.1/24
eth4            up      default         192.168.50.10/24
lo              up      default         
```
В обоих примерах мы увидем имена сетевых интерфейсов, их ip-адреса и маски подсети. Согласно схемы нам необходимы интерфейсы с сетевой адресацией 10.0.x.x. В нашем прмере это - eth1, eth2, eth3 которые согласно выводу команды ip addr имеют альтернативные имена соответственно - enp0s8, enp0s9, enp0s10

Создаём файл /etc/frr/frr.conf и вносим в него следующую информацию:<br />
```
!Указание версии FRR
frr version 8.1
frr defaults traditional
!Указываем имя машины
hostname router1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
!Добавляем информацию об интерфейсе enp0s8
interface enp0s8
 !Указываем имя интерфейса
 description r1-r2
 !Указываем ip-aдрес и маску (эту информацию мы получили в прошлом шаге)
 ip address 10.0.10.1/30
 !Указываем параметр игнорирования MTU
 ip ospf mtu-ignore
 !Если потребуется, можно указать «стоимость» интерфейса
 !ip ospf cost 1000
 !Указываем параметры hello-интервала для OSPF пакетов
 ip ospf hello-interval 10
 !Указываем параметры dead-интервала для OSPF пакетов
 !Должно быть кратно предыдущему значению
 ip ospf dead-interval 30
!
interface enp0s9
 description r1-r3
 ip address 10.0.12.1/30
 ip ospf mtu-ignore
 !ip ospf cost 45
 ip ospf hello-interval 10
 ip ospf dead-interval 30

interface enp0s10
 description net_router1
 ip address 192.168.10.1/24
 ip ospf mtu-ignore
 !ip ospf cost 45
 ip ospf hello-interval 10
 ip ospf dead-interval 30 
!
!Начало настройки OSPF
router ospf
 !Указываем router-id 
 router-id 1.1.1.1
 !Указываем сети, которые хотим анонсировать соседним роутерам
 network 10.0.10.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.10.0/24 area 0 
 !Указываем адреса соседних роутеров
 neighbor 10.0.10.2
 neighbor 10.0.12.2

!Указываем адрес log-файла
log file /var/log/frr/frr.log
default-information originate always
```
После настройки файла /etc/frr/frr.conf перезапустим frr и проверим статус:<br />
``` 
root@router1:~# systemctl restart frr
root@router1:~# systemctl status frr
● frr.service - FRRouting
     Loaded: loaded (/lib/systemd/system/frr.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2023-11-09 10:44:18 UTC; 8s ago
       Docs: https://frrouting.readthedocs.io/en/latest/setup.html
    Process: 4633 ExecStart=/usr/lib/frr/frrinit.sh start (code=exited, status=0/SUCCESS)
   Main PID: 4644 (watchfrr)
     Status: "FRR Operational"
      Tasks: 10 (limit: 710)
     Memory: 15.9M
        CPU: 849ms
     CGroup: /system.slice/frr.service
             ├─4644 /usr/lib/frr/watchfrr -d -F traditional zebra mgmtd ospfd staticd
             ├─4659 /usr/lib/frr/zebra -d -F traditional -A 127.0.0.1 -s 90000000
             ├─4664 /usr/lib/frr/mgmtd -d -F traditional -A 127.0.0.1
             ├─4666 /usr/lib/frr/ospfd -d -F traditional -A 127.0.0.1
             └─4669 /usr/lib/frr/staticd -d -F traditional -A 127.0.0.1

Nov 09 10:44:14 router1 ospfd[4666]: [VTVCM-Y2NW3] Configuration Read in Took: 00:00:00
Nov 09 10:44:14 router1 frrinit.sh[4676]: [4676|ospfd] Configuration file[/etc/frr/frr.conf] processing failure: 2
Nov 09 10:44:14 router1 watchfrr[4644]: [ZJW5C-1EHNT] restart all process 4645 exited with non-zero status 2
Nov 09 10:44:18 router1 watchfrr[4644]: [QDG3Y-BY5TN] staticd state -> up : connect succeeded
Nov 09 10:44:18 router1 watchfrr[4644]: [QDG3Y-BY5TN] mgmtd state -> up : connect succeeded
Nov 09 10:44:18 router1 watchfrr[4644]: [QDG3Y-BY5TN] zebra state -> up : connect succeeded
Nov 09 10:44:18 router1 watchfrr[4644]: [QDG3Y-BY5TN] ospfd state -> up : connect succeeded
Nov 09 10:44:18 router1 watchfrr[4644]: [KWE5Q-QNGFC] all daemons up, doing startup-complete notify
Nov 09 10:44:18 router1 frrinit.sh[4633]:  * Started watchfrr
Nov 09 10:44:18 router1 systemd[1]: Started FRRouting.
```
Включим автозагрузку для сервиса:<br />
```
systemctl enable frr
```
Аналогичные шаги необходимо выполнить на двух других маршрутизаторах(ВМ router2, router3). Можно взять за основу конфигурацию первого роутера и скорректировать настройки.<br />

После настройки и рестарта сервиса frr можем проверить работу маршрутизации простым icmp-запросом к примеру с router1 до адресов из сетей 192.168.20.0 и 192.168.30.0 анонсируемых с двух других маршрутизаторов<br />
```
root@router1:~# ping 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=1.44 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=1.43 ms
^C
--- 192.168.20.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.432/1.433/1.435/0.001 ms
root@router1:~# ping 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=1.49 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=2.33 ms
^C
--- 192.168.30.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.492/1.908/2.325/0.416 ms
```
С помощью инструмента traceroute проверим путь трафика до сети 192.168.30.0
```
root@router1:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  192.168.30.1 (192.168.30.1)  1.513 ms  1.922 ms  1.833 ms
```
Логично, трафик идет по кратчайшему пути. Для иллюстрации работы ппротокола OSPF "положим" интерфейс в направлении router3 и вновь запустим traceroute<br />
```
root@router1:~# ifconfig enp0s9 down
root@router1:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  10.0.10.2 (10.0.10.2)  0.938 ms  0.833 ms  1.107 ms
 2  192.168.30.1 (192.168.30.1)  2.943 ms  2.857 ms  2.197 ms
```
Как видим маршрут перестроился.<br />

Можем проверить содержимое таблицы маршрутизации в оболочке vtysh
```
router1# show ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/100] is directly connected, eth1, weight 1, 00:52:55
O>* 10.0.11.0/30 [110/200] via 10.0.10.2, eth1, weight 1, 00:40:25
O>* 10.0.12.0/30 [110/300] via 10.0.10.2, eth1, weight 1, 00:40:25
O   192.168.10.0/24 [110/100] is directly connected, eth3, weight 1, 00:52:55
O>* 192.168.20.0/24 [110/200] via 10.0.10.2, eth1, weight 1, 00:52:49
O>* 192.168.30.0/24 [110/300] via 10.0.10.2, eth1, weight 1, 00:40:25
```
Можно отметить, что все сети у нас доступны через один и тот же интерфейс, это следствие того, что мы выключали интерфейс enp0s9 смотрящий в сторону router3.<br />

"Поднимем" интерфейс enp0s9 и сравним таблицы маршрутизации.
```
root@router1:~# vtysh

Hello, this is FRRouting (version 9.0.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# show ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/100] is directly connected, eth1, weight 1, 00:59:44
O>* 10.0.11.0/30 [110/200] via 10.0.10.2, eth1, weight 1, 00:00:07
  *                        via 10.0.12.2, eth2, weight 1, 00:00:07
O   10.0.12.0/30 [110/100] is directly connected, eth2, weight 1, 00:00:07
O   192.168.10.0/24 [110/100] is directly connected, eth3, weight 1, 00:59:44
O>* 192.168.20.0/24 [110/200] via 10.0.10.2, eth1, weight 1, 00:59:38
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, eth2, weight 1, 00:00:07
```

#### Настройка ассиметричного роутинга

Для настройки ассиметричного роутинга нам необходимо выключить блокировку ассиметричной маршрутизации: 
```
sysctl net.ipv4.conf.all.rp_filter=0
```
Далее на одном из роутеров поменяем стоимость интерфейса.
```
interface eth1
 description r1-r2
 ip address 10.0.10.1/30
 ip ospf cost 1000
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
```
```
router1# show ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/300] via 10.0.12.2, eth2, weight 1, 00:00:21
O>* 10.0.11.0/30 [110/200] via 10.0.12.2, eth2, weight 1, 00:00:21
O   10.0.12.0/30 [110/100] is directly connected, eth2, weight 1, 00:02:56
O   192.168.10.0/24 [110/100] is directly connected, eth3, weight 1, 00:02:56
O>* 192.168.20.0/24 [110/300] via 10.0.12.2, eth2, weight 1, 00:00:21
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, eth2, weight 1, 00:02:51
```

Как видим в таблицу маршрутизации попали маршруты через router3

После внесения данных настроек, мы видим, что маршрут до сети 192.168.20.0/30  теперь пойдёт через router2, но обратный трафик от router2 пойдёт по другому пути. Давайте это проверим:
1) На router1 запускаем пинг от 192.168.10.1 до 192.168.20.1:
```
root@router1:~# ping -I 192.168.10.1 192.168.20.1
PING 192.168.20.1 (192.168.20.1) from 192.168.10.1 : 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=2.14 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=1.63 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=2.83 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=2.68 ms
64 bytes from 192.168.20.1: icmp_seq=5 ttl=64 time=5.12 ms
```
2) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s9:
```
root@router2:~# tcpdump -i enp0s9
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on enp0s9, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:54:45.525658 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 42, length 64
12:54:46.526735 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 43, length 64
12:54:47.528565 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 44, length 64
12:54:48.530120 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 45, length 64
12:54:49.194466 IP router2 > ospf-all.mcast.net: OSPFv2, Hello, length 48
12:54:49.531705 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 46, length 64
12:54:50.533636 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 47, length 64
12:54:51.536872 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 48, length 64
12:54:52.537181 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 49, length 64
12:54:53.539048 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 50, length 64
12:54:54.541362 IP 192.168.10.1 > router2: ICMP echo request, id 8, seq 51, length 64
......

````
Понимаем что на этот порт приходят icmp-запросы.

3) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s8:
```
root@router2:~# tcpdump -i enp0s8
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on enp0s8, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:55:42.632012 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 99, length 64
12:55:43.634822 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 100, length 64
12:55:44.233763 IP 10.0.10.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
12:55:44.636553 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 101, length 64
12:55:45.639058 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 102, length 64
12:55:46.640709 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 103, length 64
12:55:47.643446 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 104, length 64
12:55:48.645359 IP router2 > 192.168.10.1: ICMP echo reply, id 8, seq 105, length 64
........
```
А через этот интерфейс уходят только icmp-ответы.

#### Настройка симметичного роутинга

Так как у нас уже есть один «дорогой» интерфейс, нам потребуется добавить ещё один дорогой интерфейс, чтобы у нас перестала работать ассиметричная маршрутизация. 

Так как в прошлом задании мы заметили что router2 будет отправлять обратно трафик через порт enp0s8, мы также должны сделать его дорогим и далее проверить, что теперь используется симметричная маршрутизация:

Поменяем стоимость интерфейса enp0s8 на router2:
```
root@router2:~# vtysh

Hello, this is FRRouting (version 9.0.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router2# conf t
router2(config)# interface eth1
router2(config-if)# ip ospf cost 1000
router2(config-if)# exit
router2(config)# exit
router2# sh ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/1000] is directly connected, eth1, weight 1, 00:00:13
O   10.0.11.0/30 [110/100] is directly connected, eth2, weight 1, 02:05:09
O>* 10.0.12.0/30 [110/200] via 10.0.11.1, eth2, weight 1, 00:00:13
O>* 192.168.10.0/24 [110/300] via 10.0.11.1, eth2, weight 1, 00:00:13
O   192.168.20.0/24 [110/100] is directly connected, eth3, weight 1, 02:05:3
```

После внесения данных настроек, мы видим, что маршрут до сети 192.168.10.0/30  пойдёт через router2.

Давайте это проверим:
1) На router1 запускаем пинг от 192.168.10.1 до 192.168.20.1:
```
ping -I 192.168.10.1 192.168.20.1
```
2) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s9:
```
root@router2:~# tcpdump -i enp0s9
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on enp0s9, link-type EN10MB (Ethernet), snapshot length 262144 bytes
13:37:00.844362 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 25, length 64
13:37:00.844498 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 25, length 64
13:37:01.846299 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 26, length 64
13:37:01.846343 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 26, length 64
13:37:02.847328 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 27, length 64
13:37:02.847372 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 27, length 64
13:37:03.848961 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 28, length 64
13:37:03.849056 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 28, length 64
13:37:04.850062 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 29, length 64
13:37:04.850119 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 29, length 64
13:37:05.374499 IP 10.0.11.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
13:37:05.850692 IP 192.168.10.1 > router2: ICMP echo request, id 9, seq 30, length 64
13:37:05.850733 IP router2 > 192.168.10.1: ICMP echo reply, id 9, seq 30, length 64
```
Явно видно что и запросы и ответы фиксируются на одном интерфейсе.

