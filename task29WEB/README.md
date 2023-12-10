#### Описание домашнего задания

Варианты стенда:<br />
nginx + php-fpm (laravel/wordpress) + python (flask/django) + js(react/angular);<br />
nginx + java (tomcat/jetty/netty) + go + ruby;<br />
можно свои комбинации.<br />
Реализации на выбор:<br />
на хостовой системе через конфиги в /etc;<br />
деплой через docker-compose.<br />
Для усложнения можно попросить проекты у коллег с курсов по разработке<br />
К сдаче принимается:<br />
vagrant стэнд с проброшенными на локалхост портами<br />
каждый порт на свой сайт<br />

Операции в тестовой ВМ будем выполнять от УЗ root.

Добавим официальный репозиторий Docker в систему:<br />
```yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo```

```
[root@dynweb ~]# yum repolist
Failed to set locale, defaulting to C
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirror.sale-dedic.com
 * extras: mirror.sale-dedic.com
 * updates: mirror.sale-dedic.com
docker-ce-stable                                                                        | 3.5 kB  00:00:00     
(1/2): docker-ce-stable/7/x86_64/updateinfo                                             |   55 B  00:00:00     
(2/2): docker-ce-stable/7/x86_64/primary_db                                             | 118 kB  00:00:00     
repo id                                             repo name                                            status
base/7/x86_64                                       CentOS-7 - Base                                      10072
docker-ce-stable/7/x86_64                           Docker CE Stable - x86_64                              268
extras/7/x86_64                                     CentOS-7 - Extras                                      518
updates/7/x86_64                                    CentOS-7 - Updates                                    5434
repolist: 16292
```

Установим Docker:<br />
```yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y```

Добавим пользователя vagrant в группу docker:<br />
```usermod -aG docker vagrant```

Создадим папку docker, которая будет корнем для проекта:<br />
```mkdir ./docker```

Перейдем в папку и начнем создавать файл docker-compose.yml<br />
```
[root@dynweb docker]# vi ./docker-compose.yml
database:
  image: mysql:8.0 # используем готовый образ mysql от разработчиков
  container_name: database
  restart: unless-stopped
  environment:
    MYSQL_DATABASE: ${DB_NAME} # Имя и пароль базы данных будут задаваться в отдельном .env файле
    MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
  volumes:
  - ./dbdata:/var/lib/mysql # Чтобы данные базы не пропали при остановке/удалении контейнера, будем сохранять их на хост-машине
  command: '--default-authentication-plugin=mysql_native_password'
```

#### Создаём файл переменных .env:<br />
```[root@dynweb docker]# vi ./.env```
# Переменные которые будут использоваться для создания и подключения БД
DB_NAME=wordpress
DB_ROOT_PASSWORD=dbpassword
# Переменные необходимые python приложению
MYSITE_SECRET_KEY=put_your_django_app_secret_key_here
DEBUG=True

Для того чтобы объединить наши приложения, создадим сеть и будем добавлять каждый контейнер в неё:<br />
```vi ./docker-compose.yml```<br />

<pre>
[root@dynweb docker]# cat ./docker-compose.yml
base:
  image: mysql:8.0
  container_name: database
  restart: unless-stopped
  environment:
    MYSQL_DATABASE: ${DB_NAME} 
    MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
  volumes:
  - ./dbdata:/var/lib/mysql 
  command: '--default-authentication-plugin=mysql_native_password'
  <b>networks:</b>
  <b>- app-network</b>
<b>networks:</b>
  <b>app-network:</b>
    <b>driver: bridge</b>
</pre>

#### Контейнер wordpress:<br />
```
wordpress:
    image: wordpress:5.1.1-fpm-alpine # официальный образ от разработчиков
    container_name: wordpress
    restart: unless-stopped
    # на странице образа в docker hub написано, какие можно задать переменные контейнеру https://hub.docker.com/_/wordpress
    environment:
      WORDPRESS_DB_HOST: database
      WORDPRESS_DB_NAME: "${DB_NAME}" # Также импортируем переменные из .env
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: "${DB_ROOT_PASSWORD}"
    volumes:
    - ./wordpress:/var/www/html # сохраняем приложение на хост машине
    networks:
    - app-network
    depends_on:
    - database # контейнер wordpress дождется запуска БД
```    

#### Контейнер nginx:
```
nginx:
    image: nginx:1.15.12-alpine
    container_name: nginx
    restart: unless-stopped
    # Т.к. все запросы к приложениям будут проходить через nginx, пробросим под каждое приложение по порту.
    ports:
    - 8081:8081
    - 8082:8082
    - 8083:8083
    volumes:
    # будет использоваться php-fpm, необходимо смонтировать статические файлы wordpress:
    - ./wordpress:/var/www/html
    - ./nginx:/etc/nginx/conf.d # монтируем конфиг
    networks:
    - app-network
    depends_on: # nginx будет запускаться после всех приложений
    - wordpress
    - app
    - node
```    

Создаём директорий nginx для размещения nginx конфиг файла:<br />
[root@dynweb docker]# mkdir ./nginx<br />
Создадим nginx конфиг файл:<br />
```vi ./nginx/nginx.conf```<br />
```
server {
# Wordpress будет отображаться на 8081 порту хоста
        listen 8081;
        listen [::]:8081;
        server_name localhost;
        index index.php index.html index.htm;
# Задаем корень корень проекта, куда мы смонтировали статику wordpress
        root /var/www/html;
        location ~ /.well-known/acme-challenge {
                allow all;
                root /var/www/html;
        }
        location / {
                try_files $uri $uri/ /index.php$is_args$args;
        }
# Само fastcgi проксирование в контейнер с wordpress по 9000 порту
        location ~ \.php$ {
                try_files $uri =404;
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass wordpress:9000;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME
                $document_root$fastcgi_script_name;
                fastcgi_param PATH_INFO $fastcgi_path_info;
        }
        location = /favicon.ico {
                log_not_found off; access_log off;
        }
        location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
                expires max;
                log_not_found off;
        }
}
```

Сервер nginx для django:<br />
```
# Сервер nginx для django:
upstream django {
    server app:8000;
}
server {
# Django будет отображаться на 8082 порту хоста
        listen 8082;
        listen [::]:8082;
        server_name localhost;
        location / {
                try_files $uri @proxy_to_app;
        }
# тут используем обычное проксирование в контейнер django
        location @proxy_to_app {
                proxy_pass http://django;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_redirect off;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Host $server_name;
        }
}
```
Сервер nginx для node.js:<br />
```
# Сервер nginx для node.js:
# Node.js будет отображаться на 8083 порту хоста
server {
        listen 8083;
        listen [::]:8083;
        server_name localhost;
        location / {
                proxy_pass http://node:3000;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_redirect off;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Host $server_name;
        }
}
```

Описание раздела django:<br />
```
app:
    build: ./django # для нашего приложения нужны зависимости, поэтому собираем свой образ
    container_name: app
    restart: always
    env_file:
    - .env # импортируем в контейнер переменные из .env
    command:
      "gunicorn --workers=2 --bind=0.0.0.0:8000 mysite.wsgi:application" # команда для запуска django проекта, приложение будет работать на 8000 порту контейнера
    networks:
    - app-network
```       

Создадим папку django для размещения python файлов:<br />
```mkdir ./django```<br />
Внутри нее создадим файл requirements.txt<br />
```vi ./django/requirements.txt```<br />
С содержимым:<br />
```
Django==3.1
gunicorn==20.0.4
pytz==2020.1
```
Создадим файл manage.py там же:<br />
```vi ./django/manage.py```<br />
```
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mysite.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)
if __name__ == '__main__':
    main()
```    

В папке django создадим папке mysite:<br />
```mkdir ./django/mysite```

В этом папке создадим файл wsgi.py:<br />
```vi ./django/mysite/wsgi.py```<br />
```
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mysite.settings')
application = get_wsgi_application()
```

Создадим файл urls.py:<br />
``` vi ./django/mysite/urls.py```<br />
```
from django.contrib import admin
from django.urls import path

urlpatterns = [
    path('admin/', admin.site.urls),
]
```

Создадим файл settings.py:<br />
```vi ./django/mysite/settings.py```<br />
```
import os
import ast
from pathlib import Path

BASE_DIR = Path(__file__).resolve(strict=True).parent.parent
SECRET_KEY = os.getenv('MYSITE_SECRET_KEY', '')
DEBUG = ast.literal_eval(os.getenv('DEBUG', 'True'))
ALLOWED_HOSTS = []
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
ROOT_URLCONF = 'mysite.urls'
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
WSGI_APPLICATION = 'mysite.wsgi.application'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_L10N = True
USE_TZ = True
STATIC_URL = '/static/'
```

Добавим описание модуля node.js в ./docker-compose.yml:<br />
```
node:
    image: node:16.13.2-alpine3.15
    container_name: node
    working_dir: /opt/server # переназначим рабочую директорию для удобства
    volumes:
    - ./node:/opt/server # пробрасываем приложение в директорию контейнера
    command: node test.js # запуск приложения
    networks:
    - app-network
```   

Содержимое Dockerfile:<br />
```vi ./django/Dockerfile```<br />
```
FROM python:3.8.3
ENV APP_ROOT /src
ENV CONFIG_ROOT /config
RUN mkdir ${CONFIG_ROOT}
COPY requirements.txt ${CONFIG_ROOT}/requirements.txt
RUN pip install -r ${CONFIG_ROOT}/requirements.txt
RUN mkdir ${APP_ROOT}
WORKDIR ${APP_ROOT}
ADD . ${APP_ROOT}
```

Создаём папки node для размещения node.js файлов:<br />
```mkdir ./node```<br />
Создадим файл test.js<br />
```vi ./node/test.js```<br />
```
const http = require('http');
const hostname = '0.0.0.0';
const port = 3000;

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('Hello from node js server');
});
server.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});
```
Итоговый файл docker-compose.yml представлен отдельно в папке с ДЗ.<br />
Итого имеем структуру:<br />

![Alt text](https://github.com/catalist3/otus/blob/master/task29WEB/structure_for_web.png?raw=true)

Стартанем Docker и проверим его статус:<br />

![Alt text](https://github.com/catalist3/otus/blob/master/task29WEB/status_dock.png?raw=true)

Запустим docker-compose.yml:<br />
```docker compose -f ./docker-compose.yml up -d```

Проверим страницу wordpress 127.0.0.1:8081:<br />
![Alt text](https://github.com/catalist3/otus/blob/master/task29WEB/wordpress.png?raw=true)

Проверим страницу django 127.0.0.1:8082:<br />
![Alt text](https://github.com/catalist3/otus/blob/master/task29WEB/django.png?raw=true)

Проверим страницу node 127.0.0.1:8083:<br />
![Alt text](https://github.com/catalist3/otus/blob/master/task29WEB/node_js.png?raw=true)



















