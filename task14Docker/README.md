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