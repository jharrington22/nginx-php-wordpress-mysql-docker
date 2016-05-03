From alpine:3.2

RUN apk add --update php-fpm php-mysql php-gd php-curl php zlib zlib-dev

RUN apk add --update php-zlib

COPY php-fpm.conf /etc/php/

COPY php.ini /etc/php/

RUN adduser -u 1000 -D wordpress wordpress

RUN mkdir -p /var/www/

VOLUME /var/www/wordpress

RUN chown -R wordpress:wordpress /var/www/wordpress

ENTRYPOINT ["php-fpm", "-F"]
