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
elif cat /etc/*release | grep ^NAME | grep Ubuntu > /dev/null 2>&1; then
    OS="Ubuntu"
    if [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'trusty' ] ;then
        OS_VER="Ubuntu14"
    elif [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'xenial' ] ;then
        OS_VER="Ubuntu16"
    elif [ $(lsb_release -c | grep Codename | awk '{print $2}') == 'bionic' ] ;then
        OS_VER="Ubuntu18"
    fi
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

if [ $OS_VER == 'CentOS6' ] || [ $OS_VER == 'CentOS7' ] || [ $OS_VER == 'CentOS8' ] ;
then
  yum update -y
  echo '>> Setting timezone to America/New_York and installing NTP'
  timedatectl set-timezone Asia/Ho_Chi_Minh
  yum install -y ntp
  systemctl start ntpd
  systemctl enable ntpd

  isSwapOn=$(swapon -s | tail -1)
  if [[ "$isSwapOn" == "" ]]; then
    echo '>> Configuring swap'
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'
  fi
fi

if [ $OS == 'Amazon Linux AMI' ];
then
  yum install -y httpd24 php72 php72-mysqlnd

  echo '>> Add your user (in this case, ec2-user) to the apache group.'
  usermod -a -G apache ec2-user

  echo '>> Change the group ownership of /var/www and its contents to the apache group.'
  chown -R ec2-user:apache /var/www
fi

if [ $OS == 'Amazon Linux 2' ];
then
  echo '>> Installing Apache2'
  yum install -y httpd
  systemctl start httpd.service
  systemctl enable httpd.service

  echo '>> Installing PHP7.2'
  #EC2 :  Amazon Linux 2 AMI
  amazon-linux-extras install -y php7.2

  echo '>> Add your user (in this case, ec2-user) to the apache group.'
  usermod -a -G apache ec2-user

  echo '>> Change the group ownership of /var/www and its contents to the apache group.'
  chown -R ec2-user:apache /var/www
fi
