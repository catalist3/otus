Описание домашнего задания

1. Следуя шагам из документа https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install  установить и настроить загрузку по сети для дистрибутива CentOS 8.
В качестве шаблона воспользуйтесь репозиторием https://github.com/nixuser/virtlab/tree/main/centos_pxe 
2. Поменять установку из репозитория NFS на установку из репозитория HTTP.
3. Настроить автоматическую установку для созданного kickstart файла (*) Файл загружается по HTTP.

После выполнения команды vagrant up мы получим две ВМ, pxeserver и pxeclient но изначально pxeclient будет без установленной внутри ОС. Манипуляции по настройке учебного стенда будем выполнять вручную.

#### Настройка Web-сервера

Для того, чтобы отдавать файлы по HTTP нам потребуется настроенный веб-сервер. Использовать будем Apache.
```
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
yum install httpd
```

Далее скачаем образ CentOS-8.4.2105-x86_64-dvd1.iso, не имеет значения каким способом это сделать, главное доставить его содержимое на тестовый pxeserver. Смонитруем образ:
```
mount -t iso9660 CentOS-8.4.2105-x86_64-dvd1.iso /mnt -o loop,ro
```
Создадим директорию для содержимого скачанного образа и скопируем данные:
```
mkdir /iso
cp -r /mnt/* /iso
```
И дадаим права на папку:
```
chmod -R 755 /iso
```
Создадим дополнительный конфигурационный файл pxeboot.conf в папке /etc/httpd/conf.d. Apache использует конфиг-файлы из этой директории  через инструкцию IncludeOptional. 

Содержимое pxeboot.conf:
```
Alias /centos8 /iso
<Directory /iso>
    Options Indexes FollowSymLinks
    Require all granted
</Directory>
```

После, запусти веб-сервер и проверим его работу:

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/apache_check.png?raw=true)

#### Настройка TFTP-сервера

Установим и включим TFTP-сервер:
```
yum install tftp-server
systemctl start tftp.service
```
В рабочем каталоге tftp-сервера /var/lib/tftpboot создадим какталог для хранения меню загрузки и внутри него меню-файл
```
mkdir /var/lib/tftpboot/pxelinux.cfg
vi /var/lib/tftpboot/pxelinux.cfg/default
```
Перейдем в папку /tmp и распакуем syslinux-tftpboot-6.04-5.el8.noarch.rpm. Из получившейся папки tftpboot скоипруем следующие файлы "pxelinux.0 ldlinux.c32 libmenu.c32 libutil.c32 menu.c32 vesamenu.c32" в рабочую директорию tftp-сервера /var/lib/tftpboot/. Туда же добавим initrd.img,vmlinuz.
```
rpm2cpio /iso/BaseOS/Packages/syslinux-tftpboot-6.04-5.el8.noarch.rpm | cpio -dimv
cd tftpboot
cp pxelinux.0 ldlinux.c32 libmenu.c32 libutil.c32 menu.c32 vesamenu.c32 /var/lib/tftpboot/
cp /iso/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/
```
По итогу имеем рабочую директорию tft-сервера со следующим содержимым:

```
[root@pxeserver tftpboot]# ls -la /var/lib/tftpboot/
total 76916
drwxr-xr-x.  3 root root      170 Oct 15 16:33 .
drwxr-xr-x. 37 root root     4096 Oct 15 15:28 ..
-rwxr-xr-x.  1 root root 68936496 Oct 15 16:33 initrd.img
-rw-r--r--.  1 root root   116064 Oct 15 16:16 ldlinux.c32
-rw-r--r--.  1 root root    23684 Oct 15 16:16 libmenu.c32
-rw-r--r--.  1 root root    22804 Oct 15 16:16 libutil.c32
-rw-r--r--.  1 root root    26272 Oct 15 16:16 menu.c32
-rw-r--r--.  1 root root    42376 Oct 15 16:16 pxelinux.0
drwxr-xr-x.  2 root root       21 Oct 15 15:43 pxelinux.cfg
-rw-r--r--.  1 root root    26788 Oct 15 16:16 vesamenu.c32
-rwxr-xr-x.  1 root root  9547380 Oct 15 16:33 vmlinuz
```
Перезапустим TFTP-сервер и добавляем его в автозагрузку:
```
systemctl restart tftp.service 
systemctl enable tftp.service
```
#### Настройка DHCP-сервера


```
yum install dhcp-server
```

Правим конфигурационный файл сервера vi /etc/dhcp/dhcpd.conf:

```
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;

#Указываем сеть и маску подсети, в которой будет работать DHCP-сервер
subnet 10.0.0.0 netmask 255.255.255.0 {
        #Указываем шлюз по умолчанию, если потребуется
        #option routers 10.0.0.1;
        #Указываем диапазон адресов
        range 10.0.0.100 10.0.0.120;

        class "pxeclients" {
          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
          #Указываем адрес TFTP-сервера
          next-server 10.0.0.20;
          #Указываем имя файла, который надо запустить с TFTP-сервера
          filename "pxelinux.0";
        }
}
```
Запускаем dhcp-сервер и пробуем провести установку ОС на тестовую виртуальную машину(pxeclient).

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/start_tftp_install.png?raw=true)

После настриваем необходимые параметры установки и, при необходимости, указываем вручную репозиторий - http://10.0.0.20/centos8/BaseOS 

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/manual_repo.png?raw=true)

Процесс установки:

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/install_process.png?raw=true)

#### Настройка автоматической установки

Для процесса автоматической установки нам понядобиться файл ответов ks.cfg. Создадим его vi /iso/ks.cfg со следующим содержимым:
```
#version=RHEL8

ignoredisk --only-use=sda
autopart --type=lvm

clearpart --all --initlabel --drives=sda
graphical

keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8

url --url=http://10.0.0.20/centos8/BaseOS/

network  --bootproto=dhcp --device=enp0s3 --ipv6=auto --activate
network  --bootproto=dhcp --device=enp0s8 --onboot=off --ipv6=auto --activate
network  --hostname=otus-pxe-client

rootpw --iscrypted $6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ.

firstboot --enable
skipx
services --enabled="chronyd"

timezone Europe/Moscow --isUtc

user --groups=wheel --name=val --password=$6$ihX1bMEoO3TxaCiL$OBDSCuY.EpqPmkFmMPVvI3JZlCVRfC4Nw6oUoPG0RGuq2g5BjQBKNboPjM44.0lJGBc7OdWlL17B3qzgHX2v// --iscrypted --gecos="val"

%packages
@^minimal-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
%anaconda

pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty

%end
```

Добавляем параметр 4-м пунктом в меню загрузки - vi /var/lib/tftpboot/pxelinux.cfg/default по подобию:
```
........
label 4
       menu label ^ Auto-install CentOS 8.4
       #Загрузка данного варианта по умолчанию
       menu default
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.ks=http://10.0.0.20/centos8/ks.cfg inst.repo=http://10.0.0.20/centos8/
```       
Отличие от остальных пунктов по сути состоит в добавлении параметра inst.ks, в котором указан адрес kickstart-файла.

Перезагружаем виртуальную машину, попадаем в меню и видим 4-й вариант установки:

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/auto_install_start.png?raw=true)

Как итог работы варианта автоматической установки:

![Alt text](https://github.com/catalist3/otus/blob/master/task19TFTP/itog_auto_install.png?raw=true)