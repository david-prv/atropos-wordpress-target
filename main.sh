#!/bin/bash

file=/var/www/html/wp-config.php
if [ -e "$file" ]; then
    echo "[+] Launching..."

    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

    a2enmod rewrite
    a2enmod actions

    service mariadb start
    service apache2 start
    service redis-server start

    ( trap exit SIGINT ; read -r -d '' _ </dev/tty )

    exit
fi

chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

a2enmod rewrite
a2enmod actions

echo "[+] Starting mysql"
service mariadb start

echo "[+] Starting apache"
service apache2 start

echo "[+] Starting redis"
service redis-server start

echo "[+] Installing wordpress"

tar xvf /tmp/wordpress-6.7.1.tar.gz -C /var/www/html
rm /tmp/wordpress-6.7.1.tar.gz
mv /var/www/html/wordpress/* /var/www/html
rm -rf /var/www/html/wordpress
mv /tmp/harness /var/www/html/wp-content/plugins

chown www-data:www-data -R /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

#wp core download \
#  --path=/var/www/html \
#  --version=6.7.1 \
#  --locale=en_US

wp config create \
  --dbname=vulnbox \
  --dbuser=app \
  --dbpass=vulnerables \
  --dbhost="127.0.0.1"

wp config set WP_MEMORY_LIMIT 512M
wp config set WP_DEBUG false --raw
wp config set WP_DEBUG_DISPLAY false --raw
#wp config set WP_DEBUG true --raw
#wp config set WP_DEBUG_LOG "/tmp/wp-errors.log"

wp db create

wp core install \
  --title="Vulnbox" \
  --admin_user="admin" \
  --admin_password="admin" \
  --admin_email="dade00003@stud.uni-saarland.de" \
  --url="http://127.0.0.1:8000/" \
  --skip-email

echo "[+] Installing plugins"

#git clone https://github.com/david-prv/vulnerable-wordpress-plugins -b main /tmp/cvwp || exit 1
#mv /tmp/cvwp/* /var/www/html/wp-content/plugins/
#rm -rf /tmp/cvwp

cp -r /tmp/plugins/* /var/www/html/wp-content/plugins
rm -rf /tmp/plugins

# install redis cache and activate all
wp plugin install redis-cache
wp plugin activate --all

chown www-data:www-data -R /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

echo "[!] Press CTRL+C when you are finished with the web setup"
echo "[!] Do NOT forget to move browser_data.json to /dev/shm !!!"

tail -f /var/log/apache2/*.log &

# idle waiting for abort from user
( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C

echo "[+] Enabling persistent object cache support"

# install new wpdb class extension
patch /var/www/html/wp-includes/class-wpdb.php < /tmp/wpdb-enable-cache.patch || exit 1
rm /tmp/wpdb-enable-cache.patch

echo "[+] Instrumenting wordpress core API"

# run custom instrumentation for advanced crash detection
php /tmp/atropos-instrumentation/src/instrumentor.php /var/www/html
rm -rf /tmp/atropos-instrumentation

echo "[+] Generating harness files"

# harness generation
cp /dev/shm/browser_data.json /var/www/html/wp-content/plugins/harness
python3 /var/www/html/wp-content/plugins/harness/generate_harness.py

rm /var/www/html/wp-content/plugins/harness/generate_harness.py
rm -rf /var/www/html/wp-content/plugins/harness/entrypoints/

chown www-data:www-data -R /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

echo "[!] Instrumenting source code"

# webfuzz instrumentation
# php /tmp/php-instrumentor/src/instrumentor.php --verbose --method file --policy edge --dir /var/www/html/
# chown -R www-data:www-data /var/www/html_instrumented/
rm -rf /tmp/php-instrumentor;

echo "[!] Press CTRL+C when you are finished with the login"

#mv /var/www/html /var/www/html_orig; mv /var/www/html_instrumented /var/www/html

# idle waiting for abort from user
( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C
# cat /dev/shm/webfuzz_cov.txt
# cp /dev/shm/webfuzz_cov.txt /

#mv /var/www/html /var/www/html_instrumented; mv /var/www/html_orig /var/www/html
#rm -rf /var/www/html_instrumented

# webfuzz instrumentation
# runuser -u www-data -- cp -pr /var/www/html /tmp/
# runuser -u www-data -- php /tmp/php-instrumentor/src/instrumentor.php --verbose --method file --policy edge --dir /tmp/html
# rm -rf /tmp/php-instrumentor; rm -rf /var/www/html; rm -rf /tmp/html
# mv /tmp/html_instrumented /var/www/html

echo "[+] Dumping SQL database"

mysqldump --user=app --password=vulnerables --host=localhost vulnbox --result-file=/dev/shm/dump.sql
chmod 777 /dev/shm/dump.sql

service mariadb stop
service apache2 stop
