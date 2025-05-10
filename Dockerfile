FROM webapp-base

# php configuration file
COPY php.ini /etc/php/7.4/apache2/php.ini

# files for wordpress
COPY wpdb-enable-cache.patch /tmp/wpdb-enable-cache.patch
COPY wordpress-6.7.1.tar.gz /tmp/wordpress-6.7.1.tar.gz
COPY harness /tmp/harness
COPY plugins /tmp/plugins

# remove unnecessary files from /tmp
RUN rm -rf /tmp/php-src
WORKDIR /var/www/html

# based on https://github.com/conetix/docker-wordpress-cli
RUN apt-get update --allow-releaseinfo-change && apt-get install -y sudo less dnsutils

# install redis-server for object cache
RUN apt-get install redis-server -y && service redis-server start && service --status-all | grep redis-server

# install WP CLI as wordpress command-line interface
RUN curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
COPY wrapper.sh /bin/wp
RUN chmod +x /bin/wp-cli.phar /bin/wp
RUN git clone https://github.com/david-prv/atropos-instrumentation.git /tmp/atropos-instrumentation && \
    cd /tmp/atropos-instrumentation && \
    composer install
COPY browser_data.php /var/www/html/
COPY 000-default.conf /etc/apache2/sites-enabled/
RUN chown www-data:www-data -R /var/www/html && \
    rm /var/www/html/index.html
COPY copy_html.sh /
RUN chmod +x /copy_html.sh
RUN service mariadb start && \
    sleep 3 && \
    mysql -uroot -pvulnerables -e "CREATE USER app@localhost IDENTIFIED BY 'vulnerables';CREATE DATABASE vulnbox;GRANT ALL privileges ON vulnbox.* TO 'app'@localhost;"
    
RUN apt-get autoremove -y

EXPOSE 80
COPY main.sh /

ENTRYPOINT ["/bin/bash"]
