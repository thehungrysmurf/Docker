FROM nginx:1.13.5-alpine

MAINTAINER Alt Three <support@alt-three.com>

EXPOSE 8000
CMD ["/sbin/entrypoint.sh"]
ARG cachet_ver
ENV cachet_ver ${cachet_ver:-master}

ENV COMPOSER_VERSION 1.4.1

# Using repo packages instead of compiling from scratch
ADD https://php.codecasts.rocks/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub
RUN echo "@php http://php.codecasts.rocks/v3.5/php-7.0" >> /etc/apk/repositories
RUN apk add --no-cache --update \
    postgresql-client \
    postgresql \
    mysql-client \
    php7 \
    php7-redis@php \
    php7-apcu \
    php7-bcmath \
    php7-dom \
    php7-ctype \
    php7-curl \
    php7-fpm \
    php7-gd \
    php7-iconv \
    php7-intl \
    php7-json \
    php7-mbstring \
    php7-mcrypt \
    php7-mysqlnd \
    php7-opcache \
    php7-openssl \
    php7-pdo \
    php7-pdo_mysql \
    php7-pdo_pgsql \
    php7-pdo_sqlite \
    php7-phar \
    php7-posix \
    php7-session \
    php7-soap \
    php7-xml \
    php7-zip \
    php7-zlib \
    wget sqlite git sudo curl bash grep \
    supervisor

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php7/error.log && \
    ln -sf /dev/stderr /var/log/php7/error.log

RUN addgroup -S www-data
RUN adduser -S -s /bin/bash -G www-data www-data

RUN touch /var/run/nginx.pid /var/run/php5-fpm.pid && \
    chown -R www-data:www-data /var/run/nginx.pid /var/run/php5-fpm.pid

RUN echo 'www-data ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p /var/www/html
RUN mkdir -p /usr/share/nginx/cache
RUN mkdir -p /var/cache/nginx && \
    mkdir -p /var/lib/nginx && \
    chown -R www-data:www-data /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/

RUN ln -s /usr/bin/php7 /usr/bin/php

# Install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

WORKDIR /var/www/html/
USER www-data

RUN wget https://github.com/cachethq/Cachet/archive/${cachet_ver}.tar.gz && \
    tar xzvf ${cachet_ver}.tar.gz --strip-components=1 && \
    chown -R www-data /var/www/html && \
    rm -r ${cachet_ver}.tar.gz && \
    composer global require "hirak/prestissimo:^0.3" && \
    composer install --no-dev -o && \
    rm -rf bootstrap/cache/*

COPY conf/php-fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
COPY conf/.env.docker /var/www/html/.env
COPY entrypoint.sh /sbin/entrypoint.sh
