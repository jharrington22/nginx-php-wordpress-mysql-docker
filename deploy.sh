#!/bin/bash -e

# Remember to add WORDPRESS_DIR as an ENV or specify it here.. 
# WORDPRESS_DIR=<your_wordpress_source>

if [ -z ${WORDPRESS_DIR} ]; then
  echo "Please set your WORDPRESS_DIR environment variable"
  echo "export WORDPRESS_DIR=<you_wordpress_source>"
  exit 1
fi

DOCKER_BUILD_DIR=${PWD}

PHP_FPM_DOCKER=${DOCKER_BUILD_DIR}/php-fpm

PHP_FPM_IMAGE="php-fpm-dev"

NGINX_DOCKER=${DOCKER_BUILD_DIR}/nginx

NGINX_IMAGE="nginx-dev"

MYSQL_DUMP_DIR=${DOCKER_BUILD_DIR}/.mysql_dumps

MYSQL_DUMP_BACKUP=${MYSQL_DUMP_DIR}/wordpress-$(date +%Y%m%d-%H%M%S).sql.gz

IMAGES_TO_KEEP=5

# Clean up images
#NGINX_IMAGES=${$(docker images | grep ${NGINX_IMAGE} | sort -n | wc -l)//[[:space:]]/}
NGINX_IMAGES=$(echo "$(docker images | grep ${NGINX_IMAGE} | sort -n | wc -l)" | sed s/\ //g)
if [[ ${NGINX_IMAGES} -gt ${IMAGES_TO_KEEP} ]]
then
  NGINX_REMOVE=$(expr ${NGINX_IMAGES} - ${IMAGES_TO_KEEP})
  echo "Cleaning up ${NGINX_IMAGE} images.. "
  for image_version in $(docker images | grep ${NGINX_IMAGE} | sort -n | awk '{ print $2 }' | head -n ${NGINX_REMOVE})
    do docker rmi ${NGINX_IMAGE}:${image_version}
  done
  echo "Complete!"
fi

#PHP_FPM_IMAGES=${$(docker images | grep ${PHP_FPM_IMAGE} | sort -n | wc -l)//[[:space:]]/}
PHP_FPM_IMAGES=$(echo "$(docker images | grep ${PHP_FPM_IMAGE} | sort -n | wc -l)" | sed s/\ //g)
if [[ ${PHP_FPM_IMAGES} -gt ${IMAGES_TO_KEEP} ]]
then
  PHP_FPM_REMOVE=$(expr ${PHP_FPM_IMAGES} - ${IMAGES_TO_KEEP})
  echo "Cleaning up ${PHP_FPM_IMAGE} images.. "
  for image_version in $(docker images | grep ${PHP_FPM_IMAGE} | sort -n | awk '{ print $2 }' | head -n ${PHP_FPM_REMOVE})
    do docker rmi ${PHP_FPM_IMAGE}:${image_version}
  done
  echo "Complete!"
fi

if ! docker ps | grep -q mysql
then
  MYSQL_CONTAINER=$(echo "$(docker ps -a --filter=name=mysql | grep -v CONTAINER | wc -l)" | sed s/\ //g)
  if ! [ ${MYSQL_CONTAINER} == "0" ]
  then
    echo "Removing mysql container"
    docker rm -v mysql
  fi
  docker run -p 3306:3306 --name mysql -d -e MYSQL_DATABASE=wordpress -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql
  sleep 10
  MYSQL_DUMP_RESTORE=$(ls ${MYSQL_DUMP_DIR}/wordpress-*.sql.gz | tail -n 1)
  echo -n "Restoring db.."
  /usr/bin/gzip -cd ${MYSQL_DUMP_RESTORE} | mysql -u root -h dockerhost wordpress
  echo "Done"
else
  echo -n "Backing up mysql db.."
  mysqldump -u root -h dockerhost wordpress | gzip > ${MYSQL_DUMP_BACKUP}
  if [ $? = 0 ]
  then
    echo " Complete!"
  else
    echo " Failed!"
    exit 1
  fi
fi

cd ${PHP_FPM_DOCKER}

PHP_FPM_VERSION=$(docker images | grep ${PHP_FPM_IMAGE} | sort -n | awk '{ print $2 }' | tail -n 1)

if [ -z ${PHP_FPM_VERSION} ]
then
  PHP_FPM_VERSION=0.1
else
  if echo ${PHP_FPM_VERSION} | grep -q "0\.[0-8]"
  then
    PHP_FPM_VERSION=0$(echo "0.1+${PHP_FPM_VERSION}" | bc)
  else
    PHP_FPM_VERSION=$(echo "${PHP_FPM_VERSION}+0.1" | bc)
  fi
fi

# Check if image is running and backup uploads folder
if [ $(docker ps --filter name=php-fpm-dev | wc -l) = 2 ]
then
  echo -n "Backing up uploads and plugins directory.. "
  rm -rf ${DOCKER_BUILD_DIR}/php-fpm/wordpress/uploads
  rm -rf ${DOCKER_BUILD_DIR}/php-fpm/wordpress/plugins
  docker run -v ${DOCKER_BUILD_DIR}/php-fpm/wordpress:/root/wordpress --volumes-from php-fpm-dev --name wordpress-uploads-backup alpine:3.2 cp -fR /var/www/wordpress/wp-content/{uploads,plugins} /root/wordpress/wp-content/
  docker rm -v wordpress-uploads-backup
  echo "Complete!"
fi

echo "Copying files from ${WORDPRESS_DIR} to ${DOCKER_BUILD_DIR}/php-fpm .."

rsync -aP --exclude=".git" --delete --exclude="uploads" --exclude="plugins" ${WORDPRESS_DIR} ${DOCKER_BUILD_DIR}/php-fpm

echo "Finished copy!"

echo "Copying plugins from ${WORDPRESS_DIR}/wp-content/{uploads,plugins} to ${DOCKER_BUILD_DIR}/php-fpm/wordpress/wp-content/ .."

rsync -aP --exclude=".git" ${WORDPRESS_DIR}/wp-content/{uploads,plugins} ${DOCKER_BUILD_DIR}/php-fpm/wordpress/wp-content/

echo "Finished copying plugins and uploads"

echo -n "Building ${PHP_FPM_IMAGE}:${PHP_FPM_VERSION}.."

PHP_FPM_BUILD_LOG=$(docker build -t ${PHP_FPM_IMAGE}:${PHP_FPM_VERSION} .)

echo " Complete!"

PHP_FPM_ID=$(echo ${PHP_FPM_BUILD_LOG} | grep -o "Successfully built.*" | awk '{ print $3 }')

echo "PHP-FPM ID: ${PHP_FPM_ID}"

docker stop ${PHP_FPM_IMAGE} > /dev/null 2>&1
if [ $? = 0 ]
then
  docker rm -v ${PHP_FPM_IMAGE}
  echo "Deleted: ${PHP_FPM_IMAGE}"
fi

docker run -d --link mysql:db --name ${PHP_FPM_IMAGE} ${PHP_FPM_ID}

cd ${NGINX_DOCKER}

NGINX_VERSION=$(docker images | grep ${NGINX_IMAGE} | sort -n | awk '{ print $2 }' | tail -n 1)

if [ -z ${NGINX_VERSION} ]
then
  NGINX_VERSION=0.1
else
  if echo ${NGINX_VERSION} | grep -q "0\.[0-8]"
    then
      NGINX_VERSION=0$(echo "0.1+${NGINX_VERSION}" | bc)
    else
      NGINX_VERSION=$(echo "${NGINX_VERSION}+0.1" | bc)
  fi
fi

echo -n "Building ${NGINX_IMAGE}:${NGINX_VERSION}.."

NGINX_BUILD_LOG=$(docker build -t ${NGINX_IMAGE}:${NGINX_VERSION} .)

echo " Complete!"

NGINX_ID=$(echo ${NGINX_BUILD_LOG} | grep -o "Successfully built.*" | awk '{ print $3 }')

echo "Nginx ID: ${NGINX_ID}"

docker stop ${NGINX_IMAGE} > /dev/null 2>&1
if [ $? = 0 ]
then
  docker rm -v ${NGINX_IMAGE}
  echo "Deleted: ${NGINX_IMAGE}"
fi

docker run -d -p 80:80 -p 443:443 --name ${NGINX_IMAGE} --volumes-from $PHP_FPM_IMAGE --link ${PHP_FPM_IMAGE}:php-fpm ${NGINX_ID}
