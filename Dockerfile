#
# Builder
#

FROM composer as composer

COPY ./ /app

RUN composer --no-dev install

#
# Builder
#
FROM node as builder

# Dependencies
RUN apt-get update && apt-get install -y \
		unzip \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

COPY --from=composer /app /app

# Need the Envato Token to download the HTML Template.
ARG NPM_CONFIG_ENVATO_TOKEN

WORKDIR /app/html/themes/contrib/sailor

RUN npm install --unsafe-perm --production

#
# Service
#
FROM drupal:8-apache

# Dependencies
RUN apt-get update && apt-get install -y \
		mysql-client \
    imagemagick \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

RUN a2enmod env

# install the PHP extensions we need
RUN set -ex \
	&& buildDeps=' \
		libjpeg62-turbo-dev \
		libpng12-dev \
		libpq-dev \
    libfreetype6-dev \
	' \
	&& apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
    --with-freetype-dir=/usr \
	&& docker-php-ext-install -j "$(nproc)" gd exif \
	&& apt-get purge -y --auto-remove $buildDeps

# Set the max upload size.
RUN { \
		echo 'upload_max_filesize = 32M'; \
		echo 'post_max_size = 32M'; \
} > /usr/local/etc/php/conf.d/upload-filesize.ini

COPY --from=builder /app /var/www

ENV PATH="/var/www/vendor/bin:${PATH}"

RUN mkdir -p /var/www/tmp \
  && mkdir -p /var/www/html/sites/default/files

# Set the permissions.
RUN chmod -R +r /var/www/html
  && chown -R www-data:www-data /var/www/html/sites/default/files \
  && chown -R www-data:www-data /var/www/tmp