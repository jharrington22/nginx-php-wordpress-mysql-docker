nginx-php-wordpress-mysql-docker
================================

## About

Setup a local development environment for Wordpress using Nginx, PHP-FPM, Wordpress and MYSQL docker containers. 

This repository uses docker-compose to link everything together.

The only required configuration is to set the environment variable `WORDPRESS_DIR` which will tell the php-fpm container where the core wordpress files are located on your local machine. 

eg. 

`export WORDPRESS_DIR=/Users/jharrington/wordpress`

## Setup

Clone repo
`git@github.com:jharrington22/nginx-php-wordpress-mysql-docker.git`

`cd nginx-php-wordpress-mysql-docker`

Set ENV for Wordpress core files location
`export WORDPRESS_DIR=<Wordpress directory>`

Build images
`docker-compose build`

Bring up environment
`docker-compose up`

Next browse to http://localhost or if you are using a Mac or Windows http://dockerhost
