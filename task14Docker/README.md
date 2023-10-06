Задача:

Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен
отдавать кастомную страницу.

Определите разницу между контейнером и образом

Ответьте на вопрос: Можно ли в контейнере собрать ядро?

Собранный образ необходимо запушить в docker hub и дать ссылку на ваш
репозиторий.

#### Установка Docker:

Docker будет установлен на Centos 7 из репозитория, устанавливаем из под root. Добавим репозиторий: ``` yum install -y yum-utils ```  и  ``` yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo ```

Установим послендюю версию ``` yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ```

После установки запустим и проверим ``` systemctl start docker ``` и ``` docker run hello-world ```
![Alt text](https://github.com/catalist3/otus/blob/master/task14Docker/images/Docker_Hello_world.jpg?raw=true)

Переходим к созданию образа:
Для чего в отдельной папке создадим файл создания образа "Dockerfile", файл конфигурации для тестового веб-сервера "default.conf", и файл головной страницы для проверки работы nginx "index.html".

После  подготовки файлов командой ``` docker build -t customimage/alpng:ng_v1 . ``` создадим образ.
И проверим список имеющихся в локальном репозитории образов
![Alt text](https://github.com/catalist3/otus/blob/master/task14Docker/images/Docker_image_proverka.png?raw=true)
Убедившись что образ создан, запустим и проверим работу nginx
![Alt text](https://github.com/catalist3/otus/blob/master/task14Docker/images/nginx_service_proverka.png?raw=true)
После проверки образ необходимо скопировать в репозиторий на dockerhub.
С помощью команды ```docker login``` регистрируемся на docker-hub:
```
[root@localhost alpdocker]# docker login --username catalist4
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```
Протегируем образ в локальном репозитории путем до удаленного репозитория и запушим образ в dockerhub:
```
 [root@localhost alpdocker]# docker tag customimage/alpng:ng_v1 catalist4/dimon_repo:ng_v1
[root@localhost alpdocker]# docker push catalist4/dimon_repo:ng_v1
The push refers to repository [docker.io/catalist4/dimon_repo]
5d15763f2a10: Pushed
8c57530970c4: Pushed
db23489a65de: Pushed
cc2447e1835a: Mounted from library/alpine
ng_v1: digest: sha256:35ca32aabe5b386890b7c8b896731dcfc4a7b5321b331522bd33185c536eb767 size: 1153
```
Ссылка на репозиторий - https://hub.docker.com/repository/docker/catalist4/dimon_repo/general

#### Ответы на вопросы по теории

Определите разницу между контейнером и образом:

Образ можно воспринимать как неизменный шаблон виртуальной машины, контейнер же, в свою очередь, как запущенный экземпляр этого шаблона, который можно изменять в зависимости от цели.

Можно ли в контейнере собрать ядро?
```
Цитата:

"если вы обновляете ядро ​​​​хоста (например, для обычного обновления безопасности), вам также необходимо пересобрать и переустановить любые пользовательские модули. Основные дистрибутивы Linux поддерживают это, но если вы упаковали управление этим в контейнер, вы должны помнить, как перестроить контейнер с более новыми заголовками ядра и убедиться, что он не перезапустится, пока вы не перезагрузите хост. . Это может быть непросто.

На уровне Docker вы фактически создаете образ, который можно использовать только в одной очень конкретной системе. Обычно концепция состоит в том, чтобы создать образ, который можно повторно использовать в различных контекстах; вы хотите иметь возможность отправить образ в реестр и запустить его в другой системе с минимальной конфигурацией. Это сложно сделать, если образ привязан к очень конкретной версии ядра или другой зависимости на уровне хоста."

Можно сказать, что собрать ядро в контейнере можно, а вот универсальность в контексте возможности запуска Docker-образов на других ОС теряется.
```

