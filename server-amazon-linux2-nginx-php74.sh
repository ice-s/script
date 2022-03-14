#!/bin/bash
set -e
OS=""
OS_VER=""
# Check sudo user
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root or sudo"
    exit 1;
fi

# Check OS
echo "Check Your OS"
if cat /etc/*release | grep CentOS > /dev/null 2>&1; then
    OS="CentOS"
    if [ $(rpm --eval '%{centos_ver}') == '6' ] ;then
        OS_VER="CentOS6"
    elif [ $(rpm --eval '%{centos_ver}') == '7' ] ;then
        OS_VER="CentOS7"
    elif [ $(rpm --eval '%{centos_ver}') == '8' ] ;then
        OS_VER="CentOS8"
    fi
#elif cat /etc/*release | grep ^NAME | grep Ubuntu > /dev/null 2>&1; then
#    OS="Ubuntu"
#    if [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'trusty' ] ;then
#        OS_VER="Ubuntu14"
#    elif [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'xenial' ] ;then
#        OS_VER="Ubuntu16"
#    elif [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'bionic' ] ;then
#        OS_VER="Ubuntu18"
#    fi
elif cat /etc/*release | grep ^NAME | grep 'Amazon Linux AMI' > /dev/null 2>&1; then
    OS="Amazon Linux AMI"
    OS_VER="CentOS7"
elif cat /etc/*release | grep ^NAME | grep 'Amazon Linux' > /dev/null 2>&1; then
    OS="Amazon Linux 2"
    OS_VER="CentOS7"
else
    echo "Script doesn't support or verify this OS type/version"
    exit 1;
fi

echo ">> OS : $OS"
echo ">> OS Version : $OS_VER"


function setPermission() {
  echo '>> Add your user (in this case, ec2-user) to the apache group.'
  usermod -a -G nginx ec2-user

  #echo '>> Change the group ownership of /var/www and its contents to the apache group.'
  chown -R ec2-user:nginx /var/www
}

function createSwap(){
  isSwapOn=$(swapon -s | tail -1)
  if [[ "$isSwapOn" == "" ]]; then
    echo '>> Configuring swap'
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'
  fi
}

function setTimeZone(){
  cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
}

inputProject() {
  echo -n "Enter name project: "
  read PROJECT
}

function setupProject(){
  while true; do
    inputProject

    if [[ $PROJECT ]]
    then
      break
    fi
  done
  
  NGINX_CONFIG_FILE=/etc/nginx/conf.d/$PROJECT.conf;

  rm $NGINX_CONFIG_FILE -f
  touch $NGINX_CONFIG_FILE
  chmod +w $NGINX_CONFIG_FILE
  
  echo 'server {'  >> $NGINX_CONFIG_FILE
  echo '  listen 80;'  >> $NGINX_CONFIG_FILE
  echo '  index index.php index.html;'  >> $NGINX_CONFIG_FILE
  echo '  error_log  /var/log/nginx/error.log;'  >> $NGINX_CONFIG_FILE
  echo '  access_log /var/log/nginx/access.log;'  >> $NGINX_CONFIG_FILE
  echo "  root /var/www/$PROJECT/public;"  >> $NGINX_CONFIG_FILE
  echo '  client_max_body_size 100M;'  >> $NGINX_CONFIG_FILE
  echo '  include /etc/nginx/default.d/*.conf;'  >> $NGINX_CONFIG_FILE
  echo '  location / {'  >> $NGINX_CONFIG_FILE
  echo '    try_files $uri $uri/ /index.php?$query_string;'  >> $NGINX_CONFIG_FILE
  echo '    gzip_static on;'  >> $NGINX_CONFIG_FILE
  echo '  }'  >> $NGINX_CONFIG_FILE
  echo '  location ~ \.php$ {'  >> $NGINX_CONFIG_FILE
  echo '        try_files $uri =404;'  >> $NGINX_CONFIG_FILE
  echo '        fastcgi_split_path_info ^(.+\.php)(/.+)$;'  >> $NGINX_CONFIG_FILE
  echo '        fastcgi_pass localhost:9000;'  >> $NGINX_CONFIG_FILE
  echo '        fastcgi_index index.php;'  >> $NGINX_CONFIG_FILE
  echo '        include fastcgi_params;'  >> $NGINX_CONFIG_FILE
  echo '        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;'  >> $NGINX_CONFIG_FILE
  echo '        fastcgi_param PATH_INFO $fastcgi_path_info;'  >> $NGINX_CONFIG_FILE
  echo '  }'  >> $NGINX_CONFIG_FILE
  echo '}'  >> $NGINX_CONFIG_FILE
  
  systemctl restart nginx
  rm -rf /var/www/$PROJECT
  mkdir -p /var/www/$PROJECT/public
  touch /var/www/$PROJECT/public/index.php
  echo "<?php phpinfo();?>" >>  /var/www/$PROJECT/public/index.php
  
  sudo wget https://raw.githubusercontent.com/ice-s/script/master/nginx.conf
  sudo mv -f ./nginx.conf /etc/nginx/nginx.conf
  systemctl restart nginx
}

if [[ $OS_VER == 'CentOS6' ]] || [[ $OS_VER == 'CentOS7' ]] || [[ $OS_VER == 'CentOS8' ]] ;
then
  yum update -y
  yum install git -y
  yum install figlet -y
  yum install htop -y
  cd /etc/profile.d 
  sudo wget https://raw.githubusercontent.com/ice-s/script/master/greeting.sh
  sudo chmod +x greeting.sh
  createSwap
else
  exit 1;
fi

if [[ $OS == 'Amazon Linux 2' ]];
then
  echo '>> Installing Nginx'
  yum install -y nginx
  systemctl start nginx
  systemctl enable nginx

  echo '>> Installing PHP7.4'
  amazon-linux-extras install -y php7.4
  yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis
  
  #/etc/php-fpm.d/www.conf
  #
  #listen.owner = ec2-user
  #listen.group = nginx
  #listen.mode = 0660
  #
  sudo sed -i "s/^user = apache$/user = ec2-user/" /etc/php-fpm.d/www.conf
  sudo sed -i "s/^group = apache$/group = nginx/" /etc/php-fpm.d/www.conf
 
  sudo sed -i "s/^pm.max_children = 50$/pm.max_children = 14/" /etc/php-fpm.d/www.conf
  sudo sed -i "s/^pm.start_servers = 5$/pm.start_servers = 5/" /etc/php-fpm.d/www.conf
  sudo sed -i "s/^pm.min_spare_servers = 5$/pm.min_spare_servers = 5/" /etc/php-fpm.d/www.conf
  sudo sed -i "s/^pm.max_spare_servers = 35$/pm.max_spare_servers = 10/" /etc/php-fpm.d/www.conf
  
  systemctl enable php-fpm
  systemctl restart php-fpm
  
  cd /
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  setupProject
  setPermission
  
  #rpm -Uvh https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-x.x.x-1nodesource.x86_64.rpm
  rpm -Uvh https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-16.13.1-1nodesource.x86_64.rpm
  npm install pm2 -g
  
  amazon-linux-extras install epel
  yum install redis -y
  systemctl start redis.service
fi
