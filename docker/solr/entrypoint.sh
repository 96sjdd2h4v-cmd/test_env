#!/bin/sh
set -e


SITES="multisite-a.local multisite-b.local multisite-c.local multisite-d.local"

for SITE in $SITES; do
  echo "Configuring site: $SITE..."
  
  #Modules inschakelen voor DEZE site
  /var/www/html/vendor/bin/drush --uri=https://$SITE:8443 en search_api search_api_solr -y || true
  
  # Config importeren voor DEZE site
  /var/www/html/vendor/bin/drush --uri=https://$SITE:8443 cim -y || true
  
  # Cache wissen voor DEZE site
  /var/www/html/vendor/bin/drush --uri=https://$SITE:8443 cr || true
done

# Start de hoofdservice (php-fpm)
exec "$@"