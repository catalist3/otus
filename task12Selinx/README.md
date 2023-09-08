Практика с SELinux Цель: Тренируем умение работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется.

1)Запустить nginx на нестандартном порту 3-мя разными способами:
- переключатели setsebool;
- добавление нестандартного порта в имеющийся тип;
- формирование и установка модуля SELinux. 

1) Обеспечить работоспособность приложения при включенном selinux.
 - Развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/blob/master/selinux_dns_problems/
 - Выяснить причину неработоспособности механизма обновления зоны (см. README);
 - Предложить решение (или решения) для данной проблемы;
 - Выбрать одно из решений для реализации, предварительно обосновав выбор;
 - Реализовать выбранное решение и продемонстрировать его работоспособность.

 ВЫПОЛНЕНИЕ задачи номер 1:
 При развертывании ВМ из vagrantfile веб-сервер nginx ожидаемо не запустится ввиду работающего и настроенного по умолчанию сервиса Selinux.
 ![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ErrorStartNginx.png?raw=true)

 Заходим в ВМ: vagrant ssh
 Дальнейшие действия выполняются от пользователя root.

Провери статус файерволла, корректность конфигурации Nginx и режим работы Selinux:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/Statuses.png?raw=true)
Видим что файерволл не запущен, конфигурация веб-сервера в норме, режим работы Selinux в статусе Enforcing, что означает что он будет блокировать запрещенную активность.

Для дальнейшей работы нам понадобится набор утилит для управления политиками, установим его: yum -y install policycoreutils-python
Найдем в логах (/var/log/audit/audit.log) информацию о блокировании порта и с помощью утилиты audit2why почему трафик блокируется и что нам необходимо предпринять для решения проблемы:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/audit.png?raw=true)
Утилита audit2why рекомендует выполнить команду setsebool -P nis_enabled 1, ключ -P(видимо от слова permanent)позволит сохранить правило и после перезагрузки. Последуем его рекомендациям, перезапустим веб-сервер и прверим его статус:
[root@selinux ~]# setsebool -P nis_enabled on

[root@selinux ~]# systemctl restart nginx

[root@selinux ~]# systemctl status nginx

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus1.png?raw=true)
И в браузере глянем:
![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/browserstatus.png?raw=true)
Вернем всё как было с помощью команды setsebool -P nis_enabled off 

Проверить статус параметра можно командой getsebool -a | grep nis_enabled 

[root@selinux ~]# setsebool -P nis_enabled off 

[root@selinux ~]# getsebool -a | grep nis_enabled 
nis_enabled --> off

Попробуем разрешить работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип:
Узнаем используемый тип для портов веб-сервера и добавим наш целевой порт в этот тип:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/port_to_type.png?raw=true)
ПЕрезапустим веб-сервер и проверим статус:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus2.png?raw=true)
Удалим порт из типа,и попытаемся перезапустить веб-сервер:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus3.png?raw=true)

На этом этапе веб-сервер запускаться не будет, его блокирует Selinux.

Далее воспользуемся утилитой audit2allow чтобы на основе логов SELinux сделать модуль, который разрешит работу nginx на нестандартном порту:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/allowmodule.png?raw=true)

С помощью команды semodule -i nginx.pp применим сформированный модуль.
Запустим веб-сервер и проверим его статус:

![Alt text](https://github.com/catalist3/otus/blob/master/task12Selinx/images/ngstatus4.png?raw=true)
