yum update

echo '>> Setting timezone to America/New_York and installing NTP'

timedatectl set-timezone Asia/Ho_Chi_Minh
yum install -y ntp
systemctl start ntpd
systemctl enable ntpd

echo '>> Configuring swap'
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

echo '>> Installing Apache, MariaDB, and PHP'

yum install -y httpd
systemctl start httpd.service
systemctl enable httpd.service