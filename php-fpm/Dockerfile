From alpine:3.2

RUN apk add --update php-fpm php-mysql php

COPY php-fpm.conf /etc/php/

COPY php.ini /etc/php/

RUN adduser -D wordpress wordpress

RUN mkdir -p /var/www/

COPY wordpress /var/www/wordpress

RUN chown -R wordpress:wordpress /var/www/wordpress

VOLUME /var/www/wordpress

ENTRYPOINT ["php-fpm", "-F"]
