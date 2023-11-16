Описание домашнего задания
1. взять стенд https://github.com/erlong15/vagrant-bind<br />
- добавить еще один сервер client2<br />
- завести в зоне dns.lab имена:<br />
- web1 - смотрит на клиент1<br />
- web2  смотрит на клиент2<br />
- завести еще одну зону newdns.lab<br />
- завести в ней запись<br />
- www - смотрит на обоих клиентов<br />

2. настроить split-dns<br />
- клиент1 - видит обе зоны, но в зоне dns.lab только web1<br />
- клиент2 видит только dns.lab<br />


#### Проверим работоспособность DNS-серверов и их конфигурацию 

<pre>
[root@ns01 ~]# ss -tulpn
Netid State      Recv-Q Send-Q      Local Address:Port                     Peer Address:Port              
udp   UNCONN     0      0               127.0.0.1:323                                 *:*                   users:(("chronyd",pid=335,fd=5))
udp   UNCONN     0      0                       *:960                                 *:*                   users:(("rpcbind",pid=373,fd=7))
udp   UNCONN     0      0           192.168.50.10:53                                  *:*                   users:(("named",pid=4572,fd=512))
udp   UNCONN     0      0                       *:68                                  *:*                   users:(("dhclient",pid=4594,fd=6))
udp   UNCONN     0      0                       *:111                                 *:*                   users:(("rpcbind",pid=373,fd=6))
udp   UNCONN     0      0                   [::1]:323                              [::]:*                   users:(("chronyd",pid=335,fd=6))
udp   UNCONN     0      0                    [::]:960                              [::]:*                   users:(("rpcbind",pid=373,fd=10))
udp   UNCONN     0      0                   [::1]:53                               [::]:*                   users:(("named",pid=4572,fd=513))
udp   UNCONN     0      0                    [::]:111                              [::]:*                   users:(("rpcbind",pid=373,fd=9))
tcp   LISTEN     0      128                     *:111                                 *:*                   users:(("rpcbind",pid=373,fd=8))
<b>tcp   LISTEN     0      10          192.168.50.10:53                                  *:*                   users:(("named",pid=4572,fd=21))</b>
tcp   LISTEN     0      128                     *:22                                  *:*                   users:(("sshd",pid=619,fd=3))
tcp   LISTEN     0      128         192.168.50.10:953                                 *:*                   users:(("named",pid=4572,fd=23))
tcp   LISTEN     0      100             127.0.0.1:25                                  *:*                   users:(("master",pid=821,fd=13))
tcp   LISTEN     0      128                  [::]:111                              [::]:*                   users:(("rpcbind",pid=373,fd=11))
tcp   LISTEN     0      10                  [::1]:53                               [::]:*                   users:(("named",pid=4572,fd=22))
tcp   LISTEN     0      128                  [::]:22                               [::]:*                   users:(("sshd",pid=619,fd=4))
tcp   LISTEN     0      100                 [::1]:25                               [::]:*                   users:(("master",pid=821,fd=14))
</pre>

Часть конфигурации ns01:<br />
```
[root@ns01 ~]# cat /etc/named.conf 
options {

    // network 
<b>	listen-on port 53 { 192.168.50.10; };</b>
	listen-on-v6 port 53 { ::1; };
.............................................
```
Часть конфигурации ns01:<br />
```
[root@ns02 ~]# cat /etc/named.conf 
options {

    // network 
<b>	listen-on port 53 { 192.168.50.11; };</b>
	listen-on-v6 port 53 { ::1; };
.........................................
```
Далее нам необходимо скорректировать настройки /etc/resolv.conf на обоих ДНС-серверах, указав их адреса перекрестно друг на друга:<br />
Т.Е. файл /etc/resolv.conf на сервере ns01 выглядит так:
```
[root@ns01 ~]# cat /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.50.11
```
А на ns02, так:
```
[root@ns02 ~]# cat /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.50.10
```

#### Добавление имён в зону dns.lab<br />
Проверим в конфигурации ДНС-серверов настройки для зоны dns.lab:

```
[root@ns01 ~]# cat /etc/named.conf
..................................
// lab's zone
zone "dns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/named/named.dns.lab";
};
..................................
```

```
[root@ns02 ~]# cat /etc/named.conf
................................
// lab's zone
zone "dns.lab" {
    type slave;
    masters { 192.168.50.10; };
    file "/etc/named/named.dns.lab";
};
.................................
```
Файл конфигурации самой зоны dns.lab:<br />
```
[root@ns01 ~]# cat /etc/named/named.dns.lab
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11
```

Добавим в файл зоны записи для имен web1 и web2.<br />
```
[root@ns01 ~]# cat /etc/named/named.dns.lab
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
```

Проверку можно выполнить банальным ping-ом:<br />
```
[root@ns02 ~]# ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=2.16 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=2.30 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=3 ttl=64 time=2.57 ms
^C
--- web1.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 2.168/2.348/2.573/0.168 ms
[root@ns02 ~]# ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from 192.168.50.16 (192.168.50.16): icmp_seq=1 ttl=64 time=3.07 ms
64 bytes from 192.168.50.16 (192.168.50.16): icmp_seq=2 ttl=64 time=1.99 ms
^C
--- web2.dns.lab ping statistics ---
```

Либо используя утилиту dig:<br />
```
[root@client ~]# dig @192.168.50.10 web2.dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.15 <<>> @192.168.50.10 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64728
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web2.dns.lab.			IN	A

<b>;; ANSWER SECTION:<b/>
<b>web2.dns.lab.		3600	IN	A	192.168.50.16</b>

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns02.dns.lab.
dns.lab.		3600	IN	NS	ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10
ns02.dns.lab.		3600	IN	A	192.168.50.11

;; Query time: 3 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Nov 14 23:12:24 UTC 2023
;; MSG SIZE  rcvd: 127
```