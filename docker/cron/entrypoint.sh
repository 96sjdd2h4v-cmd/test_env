#!/bin/sh
set -eu

touch /tmp/drupal-cron.log
chown www-data:www-data /tmp/drupal-cron.log
chmod 0640 /tmp/drupal-cron.log

exec "$@"