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

echo '>> OS : $OS'
echo '>> OS version : $OS_VER'
