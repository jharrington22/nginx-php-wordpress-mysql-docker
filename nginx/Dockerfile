FROM nginx:1.9.7

RUN ["apt-get", "update"]

RUN ["apt-get", "install", "-y", "telnet", "net-tools", "postfix"]

RUN groupadd -r wordpress \
  && useradd -r -g wordpress wordpress

COPY default.conf /etc/nginx/conf.d/

RUN mkdir -p /var/www/wordpress && chown -R wordpress:wordpress /var/www 
