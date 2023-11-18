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
<pre>
[root@ns01 ~]# cat /etc/named.conf 
options {

    // network 
<b>	listen-on port 53 { 192.168.50.10; };</b>
	listen-on-v6 port 53 { ::1; };
.............................................
</pre>
Часть конфигурации ns01:<br />
<pre>
[root@ns02 ~]# cat /etc/named.conf 
options {

    // network 
<b>	listen-on port 53 { 192.168.50.11; };</b>
	listen-on-v6 port 53 { ::1; };
.........................................
</pre>

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
Для того чтобы подчиненный днс-сервер обновил данные по зоне, добавим к номеру серийника 1-цу и перезапустим службу named. 

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
<pre>
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

<b>;; ANSWER SECTION:</b>
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
</pre>

Для записи web1:
<pre>
[root@client ~]# dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.15 <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48933
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

<b>;; ANSWER SECTION:</b>
<b>web1.dns.lab.		3600	IN	A	192.168.50.15</b>

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns02.dns.lab.
dns.lab.		3600	IN	NS	ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10
ns02.dns.lab.		3600	IN	A	192.168.50.11

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Tue Nov 14 23:50:13 UTC 2023
;; MSG SIZE  rcvd: 127
</pre>

#### Создание новой зоны и добавление в неё записей

Для того, чтобы прописать на DNS-серверах новую зону нам потребуется:<br />
 - На хосте ns01 добавить зону в файл /etc/named.conf:<br />
 ```
 // lab's newdns zone
zone "newdns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    allow-update { key "zonetransfer.key"; };
    file "/etc/named/named.newdns.lab";
};
```
Опция allow-update позволяет серверу предъявившему  RNDC-ключ обновить зону.

На хосте ns02 также добавляем информацию о зоне с указанием где данные этой зоны необходимо запросить<br />
```
// lab's newdns zone
zone "newdns.lab" {
    type slave;
    masters { 192.168.50.10; };
    file "/etc/named/named.newdns.lab";
};
```

На хосте ns01 создадим файл ```/etc/named/named.newdns.lab```<br />
Основные свойства зоны можно скопировать зоны dns.lab и добавить записи для www 

```
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201007 ; serial
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

;WWW
www             IN      A       192.168.50.15
www             IN      A       192.168.50.16
```
У файла должны быть права 660, владелец — root, группа — named.<br />
```
[root@ns01 ~]# ls -la /etc/named/named.newdns.lab
-rw-r--r--. 1 root root 703 Nov 15 02:56 /etc/named/named.newdns.lab
[root@ns01 ~]# chown root:named /etc/named/named.newdns.lab
[root@ns01 ~]# ls -la /etc/named/named.newdns.lab
-rw-r--r--. 1 root named 703 Nov 15 02:56 /etc/named/named.newdns.lab
[root@ns01 ~]# chmod g+w /etc/named/named.newdns.lab
[root@ns01 ~]# ls -la /etc/named/named.newdns.lab
-rw-rw-r--. 1 root named 703 Nov 15 02:56 /etc/named/named.newdns.lab
```

После внесения данных изменений, изменяем значение serial (добавлем +1 к значению 2711201007)<br />
 и перезапускаем named: ```systemctl restart named```
Проверим работу обычным пингом:
```
[root@ns01 ~]# ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=1.87 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=2.18 ms
^C
--- www.newdns.lab ping statistics ---


[root@client ~]# ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.021 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.087 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.090 ms
^C
--- www.newdns.lab ping statistics ---
```


Настройка Split-DNS
У нас уже есть прописанные зоны dns.lab и newdns.lab. Однако по заданию client1 должен видеть запись web1.dns.lab и не видеть запись web2.dns.lab. Client2 может видеть обе записи из домена dns.lab, но не должен видеть записи домена newdns.lab Осуществить данные настройки нам поможет технология Split-DNS.

Для настройки Split-DNS нужно:
1) Создать дополнительный файл зоны dns.lab, в котором будет прописана только одна запись:<br />
```
[root@ns01 ~]# cat /etc/named/named.dns.lab.client
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
```

2) Внести изменения в файл /etc/named.conf на хостах ns01 и ns02.<br />
Прежде всего нужно сделать access листы для хостов client и client2.<br />
Сначала сгенерируем ключи для хостов client и client2, для этого на хосте ns01 запустим утилиту tsig-keygen<br />
(ключ может генериться 5 минут и более):<br />

Ключей необходимо два, для client и client2:
```
[root@ns01 ~]# tsig-keygen
key "tsig-key" {
	algorithm hmac-sha256;
	secret "zBoFv5ZvoLjUNINY412R4Vw1/V2eh8na6p7lPP9/ZiI=";
};

[root@ns01 ~]# tsig-keygen
key "tsig-key" {
	algorithm hmac-sha256;
	secret "I7dIPDIOzADEZro2YAF9FGrx4OzjHSzTYmJ5O+L0m1M=";
};
```
Access-листы будут иметь вид:<br />
```
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
```
client имеет адрес 192.168.50.15, использует client-key и не использует client2-key, это понятно по символу ! предшествующему client2-key<br />
Аналогично для client2, он имеет адрес 192.168.50.16, использует clinet2-key и не использует client-key.

Теперь можно переходить к правке /etc/named.conf.

Технология Split-DNS реализуется с помощью описания представлений (view), для каждого отдельного acl.<br />
В каждое представление (view) добавляются только те зоны, которые разрешено видеть хостам, адреса которых указаны в access листе.<br />

Все ранее описанные зоны должны быть перенесены в модули view. Вне view зон быть недолжно, зона any должна всегда находиться в самом низу.<br />

Содержимое рабочих файлов конфигурации обоих ДНС-серверов представлено в файлах named-conf-ns01.txt и named-conf-ns02.txt прикрепленных в проекте.<br />
Для проверки настроек файлов конфигурации в методичке советуют использовать утилиту ```niamed-checkconf```, мы ей пользоваться конечно же не будем, по слухам она не очень хорошо работает. А вот ```named-checkconf``` работает как надо.<br />

После внесения данных изменений можно перезапустим (по очереди) службу named на серверах ns01 и ns02 и приступим к проверкам.

Проверка на client:
```
[vagrant@client ~]$ ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.033 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.080 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.089 ms
64 bytes from client (192.168.50.15): icmp_seq=4 ttl=64 time=0.052 ms
^C
--- www.newdns.lab ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3051ms
rtt min/avg/max/mdev = 0.033/0.063/0.089/0.023 ms
[vagrant@client ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.023 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.080 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.088 ms
64 bytes from client (192.168.50.15): icmp_seq=4 ttl=64 time=0.077 ms
^C
--- web1.dns.lab ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3023ms
rtt min/avg/max/mdev = 0.023/0.067/0.088/0.025 ms
[vagrant@client ~]$ ping web2.dns.lab
ping: web2.dns.lab: Name or service not known
[vagrant@client ~]$ 
```
На хосте мы видим, что client видит обе зоны (dns.lab и newdns.lab), однако информацию о хосте web2.dns.lab он получить не может. 

Проверка на client2:
```
[vagrant@client2 ~]$ ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.081 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.117 ms
64 bytes from client2 (192.168.50.16): icmp_seq=3 ttl=64 time=0.076 ms
^C
--- web2.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2011ms
rtt min/avg/max/mdev = 0.076/0.091/0.117/0.019 ms
[vagrant@client2 ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=2.27 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=1.39 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=3 ttl=64 time=2.16 ms
^C
--- web1.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2017ms
rtt min/avg/max/mdev = 1.393/1.943/2.271/0.391 ms
[vagrant@client2 ~]$ ping www.newdns.lab
ping: www.newdns.lab: Name or service not known
```
Тут мы понимаем, что client2 видит всю зону dns.lab и не видит зону newdns.lab
