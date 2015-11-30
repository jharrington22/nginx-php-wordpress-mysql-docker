FROM nginx:1.9.7

RUN ["apt-get", "update"]

RUN ["apt-get", "install", "-y", "telnet", "net-tools", "postfix"]

COPY default.conf /etc/nginx/conf.d/
