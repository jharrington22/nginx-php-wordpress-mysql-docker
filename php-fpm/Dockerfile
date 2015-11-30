From alpine:3.2

RUN apk add --update php-fpm php-mysql php

COPY php-fpm.conf /etc/php/

ENTRYPOINT ["php-fpm", "-F"]
