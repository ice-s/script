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
  usermod -a -G apache ec2-user

  echo '>> Change the group ownership of /var/www and its contents to the apache group.'
  chown -R ec2-user:apache /var/www
}

function createSwap(){
  isSwapOn=$(swapon -s | tail -1)
  if [[ "$isSwapOn" == "" ]]; then
    echo '>> Configuring swap'
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'
  fi
}

function setTimeZone(){
  #echo '>> Setting timezone to America/New_York and installing NTP'
  #timedatectl set-timezone Asia/Ho_Chi_Minh
  #yum install -y ntp
  #systemctl start ntpd
  #systemctl enable ntpd
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

  VHOST_FILE=/etc/httpd/conf.d/vhost.conf;

  rm $VHOST_FILE -f
  touch $VHOST_FILE
  chmod +w $VHOST_FILE
  echo '<VirtualHost *:80>'  >> $VHOST_FILE
  echo '    ServerAdmin admin@test.io'  >> $VHOST_FILE
  echo "    DocumentRoot /var/www/$PROJECT/public"  >> $VHOST_FILE
  echo "    <Directory /var/www/$PROJECT/public>"  >> $VHOST_FILE
  echo '        AllowOverride All'  >> $VHOST_FILE
  echo '    </Directory>'  >> $VHOST_FILE
  echo '</VirtualHost>'  >> $VHOST_FILE
  systemctl restart httpd.service

  mkdir -p /var/www/$PROJECT/public
  touch /var/www/$PROJECT/public/index.php
  echo "<?php phpinfo();?>" >>  /var/www/$PROJECT/public/index.php
}

if [[ $OS_VER == 'CentOS6' ]] || [[ $OS_VER == 'CentOS7' ]] || [[ $OS_VER == 'CentOS8' ]] ;
then
  yum update -y
  yum install git -y
  createSwap
else
  exit 1;
fi

if [[ $OS == 'Amazon Linux AMI' ]];
then
  yum install -y httpd24 php72 php72-mysqlnd php72-mbstring php72-xml
  cd /
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  setupProject
  setPermission
  curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
  yum install -y nodejs
fi

if [[ $OS == 'Amazon Linux 2' ]];
then
  echo '>> Installing Apache2'
  yum install -y httpd
  systemctl start httpd.service
  systemctl enable httpd.service

  echo '>> Installing PHP7.2'
  amazon-linux-extras install -y php7.2
  yum install -y php-mbstring php-xml php-gd php-zip
  cd /
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  setupProject
  setPermission
  
  curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
  yum install -y nodejs
  
  amazon-linux-extras install epel
  yum install redis -y
  systemctl start redis.service
fi

