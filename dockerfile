FROM php:8.4-cli-alpine AS base

# 1. Eerst de zware PHP/PECL extensies (wordt nu permanent gecached!)
RUN apk add --no-cache postgresql-libs \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS postgresql-dev \
    && docker-php-ext-install pdo_pgsql \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# 2. Pas aan het einde van 'base' het CA certificaat toevoegen
COPY solr-ca.cr[t] /usr/local/share/ca-certificates/
RUN apk add --no-cache ca-certificates \
    && ([ -f /usr/local/share/ca-certificates/solr-ca.crt ] && update-ca-certificates || true)

WORKDIR /var/www/html


FROM drupal:11-php8.4-fpm-alpine AS app

COPY --from=base /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=base /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Haal de officiële Composer binary op
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Kopieer het Drupal opstartscript
COPY docker/solr/entrypoint.sh /usr/local/bin/app-entrypoint.sh
RUN chmod +x /usr/local/bin/app-entrypoint.sh

# 1. Kopieer eerst alleen composer bestanden en draai de installatie
COPY composer.json composer.lock /var/www/html/
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-scripts --no-autoloader

# 2. Kopieer de rest van de applicatie
COPY --chown=82:82 . /var/www/html/

# 3. Genereer de geoptimaliseerde autoloader en zet eigendomsrechten op 82:82
RUN COMPOSER_ALLOW_SUPERUSER=1 composer dump-autoload --optimize \
    && chown -R 82:82 /var/www/html/vendor

# Pas helemaal onderaan in 'app' (vóór USER 82:82) het CA certificaat toevoegen
COPY solr-ca.cr[t] /usr/local/share/ca-certificates/
RUN apk add --no-cache ca-certificates \
    && ([ -f /usr/local/share/ca-certificates/solr-ca.crt ] && update-ca-certificates || true)

USER 82:82

ENTRYPOINT ["/usr/local/bin/app-entrypoint.sh"]
CMD ["php-fpm"]


FROM base AS cron-base

COPY docker/cron/entrypoint.sh /usr/local/bin/cron-entrypoint.sh 
RUN chmod +x /usr/local/bin/cron-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/cron-entrypoint.sh"]

CMD ["crond", "-f", "-d", "8"]

FROM cron-base AS cron-a
COPY docker/cron/crontab-a /var/spool/cron/crontabs/www-data
RUN chown root:root /var/spool/cron/crontabs/www-data \
    && chmod 0600 /var/spool/cron/crontabs/www-data

FROM cron-base AS cron-b
COPY docker/cron/crontab-b /var/spool/cron/crontabs/www-data
RUN chown root:root /var/spool/cron/crontabs/www-data \
    && chmod 0600 /var/spool/cron/crontabs/www-data