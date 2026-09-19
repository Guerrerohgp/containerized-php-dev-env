ARG PHP_VERSION=8.5
ARG NODE_VERSION=20
FROM docker.io/library/node:${NODE_VERSION}-bookworm-slim AS node
# Preserve the existing PHP_VERSION switch, including archived legacy images.
FROM docker.io/library/php:7.4-fpm-bullseye AS php-7.4
COPY bullseye-sources.list /etc/apt/sources.list
FROM docker.io/library/php:8.0-fpm-bullseye AS php-8.0
COPY bullseye-sources.list /etc/apt/sources.list
FROM docker.io/library/php:8.1-fpm-bookworm AS php-8.1
FROM docker.io/library/php:8.2-fpm-bookworm AS php-8.2
FROM docker.io/library/php:8.3-fpm-bookworm AS php-8.3
FROM docker.io/library/php:8.4-fpm-bookworm AS php-8.4
FROM docker.io/library/php:8.5-fpm-bookworm AS php-8.5
FROM php-${PHP_VERSION} AS app

LABEL maintainer="PHP Docker"

ARG WWWGROUP=1000
ARG PHP_EXTENSION_INSTALLER_VERSION=2.11.15
ARG PHP_POST_MAX_SIZE=100M
ARG PHP_UPLOAD_MAX_FILESIZE=100M
ARG PHP_MAX_EXECUTION_TIME=300
ARG PHP_SHORT_OPEN_TAG=On

WORKDIR /var/www/html

ENV TZ=UTC

# Install runtime tools without the Ubuntu PPA or recommended packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl zip unzip git supervisor sqlite3 nginx \
    && rm -rf /var/lib/apt/lists/*

# The installer removes extension build dependencies when it finishes.
RUN curl -fsSL \
    "https://github.com/mlocati/docker-php-extension-installer/releases/download/${PHP_EXTENSION_INSTALLER_VERSION}/install-php-extensions" \
    -o /usr/local/bin/install-php-extensions \
    && chmod +x /usr/local/bin/install-php-extensions \
    && case "$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')" in \
        7.4) xdebug_extension=xdebug-3.1.6 ;; \
        8.0) xdebug_extension=xdebug-3.2.2 ;; \
        8.1) xdebug_extension=xdebug-3.3.2 ;; \
        *) xdebug_extension=xdebug ;; \
    esac \
    && install-php-extensions \
        bcmath gd intl mysqli pdo_mysql pgsql pdo_pgsql zip \
        imap soap tidy redis "$xdebug_extension" opcache \
    && rm /usr/local/bin/install-php-extensions

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm /tmp/composer-setup.php \
    && curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

RUN groupadd --force -g "$WWWGROUP" sail \
    && useradd -ms /bin/bash --no-user-group -g "$WWWGROUP" -u 1337 sail

COPY start-container /usr/local/bin/start-container
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY php.ini /usr/local/etc/php/conf.d/99-sail.ini
COPY xdebug.ini /usr/local/etc/php/conf.d/99-xdebug-settings.ini
COPY fpm-env.conf /usr/local/etc/php-fpm.d/zzz-sail.conf
COPY nginx-default /etc/nginx/sites-available/default

# CLI and FPM use the same configuration in the official PHP image.
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini" \
    && sed -i \
        -e "s/\${PHP_POST_MAX_SIZE}/${PHP_POST_MAX_SIZE}/g" \
        -e "s/\${PHP_UPLOAD_MAX_FILESIZE}/${PHP_UPLOAD_MAX_FILESIZE}/g" \
        -e "s/\${PHP_MAX_EXECUTION_TIME}/${PHP_MAX_EXECUTION_TIME}/g" \
        -e "s/\${PHP_SHORT_OPEN_TAG}/${PHP_SHORT_OPEN_TAG}/g" \
        "$PHP_INI_DIR/conf.d/99-sail.ini" \
    && chmod +x /usr/local/bin/start-container

EXPOSE 80

ENTRYPOINT ["start-container"]
# Clear the upstream php-fpm CMD: Supervisor starts both FPM and Nginx.
CMD []
