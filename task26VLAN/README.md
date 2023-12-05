#### Цель домашнего задания
Научиться настраивать VLAN и LACP. 

#### Описание домашнего задания
в Office1 в тестовой подсети появляется сервера с доп интерфйесами и адресами<br />
в internal сети testLAN:<br />
- testClient1 - 10.10.10.254<br />
- testClient2 - 10.10.10.254<br />
- testServer1- 10.10.10.1<br />
- testServer2- 10.10.10.1<br />

Равести вланами:<br />
testClient1 <-> testServer1<br />
testClient2 <-> testServer2<br />

Между centralRouter и inetRouter "пробросить" 2 линка (общая inernal сеть) и объединить их в бонд, проверить работу c отключением интерфейсов

#### Предварительная настройка хостов

Перед настройкой VLAN и LACP рекомендуется установить на хосты следующие утилиты:<br />
```
vim
traceroute
tcpdump
net-tools
```

Установка пакетов на CentOS 8 Stream:<br />
```
yum install -y vim traceroute tcpdump net-tools 
```
Установка пакетов на Ubuntu 20.04:<br />
```
apt install -y vim traceroute tcpdump net-tools 
```

#### Настройка VLAN на хостах

#### Настройка VLAN на RHEL-based системах:<br />
На хосте testClient1 требуется создать файл ```/etc/sysconfig/network-scripts/ifcfg-vlan1``` со следующим содержимым:
```
VLAN=yes
TYPE=Vlan
PHYSDEV=eth1
VLAN_ID=1
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=10.10.10.254
PREFIX=24
NAME=vlan1
DEVICE=eth1.1
ONBOOT=yes
```
На testServer1 создадим подобный файл, только ip-адрес изменим на ```10.10.10.1```
После настроек перезапустим сеть на обоих ВМ ```systemctl restart NetworkManager```

Проверим настройку интерфейса и связность между testClient1 и testServer1:
<pre>
<b>[root@testClient1 ~]# ip a</b>
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 52:54:00:4d:77:d3 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global noprefixroute dynamic eth0
       valid_lft 86393sec preferred_lft 86393sec
    inet6 fe80::5054:ff:fe4d:77d3/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:07:2d:3f brd ff:ff:ff:ff:ff:ff
    inet6 fe80::40ed:18e0:dd58:ebb4/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:b5:8d:65 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.21/24 brd 192.168.56.255 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feb5:8d65/64 scope link 
       valid_lft forever preferred_lft forever
<b>5: eth1.1@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000</b>
<b>    link/ether 08:00:27:07:2d:3f brd ff:ff:ff:ff:ff:ff</b>
<b>    inet 10.10.10.254/24 brd 10.10.10.255 scope global noprefixroute eth1.1</b>
<b>       valid_lft forever preferred_lft forever</b>
<b>    inet6 fe80::a00:27ff:fe07:2d3f/64 scope link</b> 
<b>      valid_lft forever preferred_lft forever</b>
<b>[root@testClient1 ~]# ping 10.10.10.1</b>
<b>PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.</b>
<b>64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=3.04 ms</b>
<b>64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.37 ms</b>
<b>64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=1.83 ms</b>
<b>64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=2.30 ms</b>
<b>64 bytes from 10.10.10.1: icmp_seq=5 ttl=64 time=2.11 ms</b>
</pre>

#### Настройка VLAN на Ubuntu:<br />

На хосте testClient2 требуется создадим файл ```/etc/netplan/50-cloud-init.yaml``` со следующим параметрами:
```
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: true
        #В разделе ethernets добавляем порт, на котором будем настраивать VLAN
        enp0s8: {}
    #Настройка VLAN
    vlans:
        #Имя VLANа
        vlan2:
          #Указываем номер VLAN`а
          id: 2
          #Имя физического интерфейса
          link: enp0s8
          #Отключение DHCP-клиента
          dhcp4: no
          #Указываем ip-адрес
          addresses: [10.10.10.254/24]
```
На хосте testServer2 создаем аналогичный файл с другим IP-адресом ```10.10.10.1```.

#### Настройка LACP между хостами inetRouter и centralRouter

Bond интерфейс будет работать через порты eth1 и eth2. 

1) Изначально необходимо на обоих хостах добавить конфигурационные файлы для интерфейсов eth1 и eth2:

```vi /etc/sysconfig/network-scripts/ifcfg-eth1```

<pre>
#Имя физического интерфейса
<b>DEVICE=eth1</b>
#Включать интерфейс при запуске системы
ONBOOT=yes
#Отключение DHCP-клиента
BOOTPROTO=none
#Указываем, что порт часть bond-интерфейса
MASTER=bond0
#Указыаваем роль bond
SLAVE=yes
NM_CONTROLLED=yes
USERCTL=no
</pre>

У интерфейса ifcfg-eth2 идентичный конфигурационный файл, в котором нужно изменить имя интерфейса в инструкции DEVICE.

2) После настройки интерфейсов eth1 и eth2 нужно настроить bond-интерфейс, для этого создадим файл ```/etc/sysconfig/network-scripts/ifcfg-bond0```
```
vi /etc/sysconfig/network-scripts/ifcfg-bond0
```
```
DEVICE=bond0
NAME=bond0
#Тип интерфейса — bond
TYPE=Bond
BONDING_MASTER=yes
#Указаваем IP-адрес 
IPADDR=192.168.255.1
#Указываем маску подсети
NETMASK=255.255.255.252
ONBOOT=yes
BOOTPROTO=static
#Указываем режим работы bond-интерфейса Active-Backup
# fail_over_mac=1 — данная опция «разрешает отвалиться» одному интерфейсу
BONDING_OPTS="mode=1 miimon=100 fail_over_mac=1"
NM_CONTROLLED=yes
```

После создания данных конфигурационных файлов перезапускаем сеть:
```systemctl restart NetworkManager```
И проверяем создание агрегированного интерфейса:
```
[root@inetRouter ~]# ip addr
............................
6: bond0: <NO-CARRIER,BROADCAST,MULTICAST,MASTER,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 08:00:27:b6:73:86 brd ff:ff:ff:ff:ff:ff
    inet 192.168.255.1/30 brd 192.168.255.3 scope global noprefixroute bond0
       valid_lft forever preferred_lft forever
```
Аналогичные настройки осуществим на ВМ ```centralRouter```. После настроек проверим что собранный "bond" поднялся на обоих ВМ.
<pre>
3: eth1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast <b>master bond0 state UP group</b> default qlen 1000
    link/ether 08:00:27:b6:73:86 brd ff:ff:ff:ff:ff:ff
4: eth2: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast <b>master bond0 state UP group</b> default qlen 1000
    link/ether 08:00:27:7b:a2:97 brd ff:ff:ff:ff:ff:ff
</pre>

Проверим связность:
```
[root@inetRouter ~]# ping 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=4.23 ms
64 bytes from 192.168.255.2: icmp_seq=2 ttl=64 time=1.88 ms
64 bytes from 192.168.255.2: icmp_seq=3 ttl=64 time=1.32 ms
^C
--- 192.168.255.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 1.325/2.480/4.230/1.258 ms
```

Не отменяя ping подключаемся к хосту centralRouter и выключаем там интерфейс eth1:<br /> 
```[root@centralRouter ~]# ip link set down eth1```

После данного действия ping не должен пропасть, так как трафик пойдёт по-другому порту.

![Alt text](https://github.com/catalist3/otus/blob/master/task26VLAN/eth1_down.png?raw=true)
