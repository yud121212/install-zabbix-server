#!/bin/bash
echo "update......"
yum install -y epel-release
yum update -y
echo "Open firewall enable http and https"
firewall-cmd --permanent --zone=public --add-service=http 
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

echo "Step1 - Config disable selinux"
sudo setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config

echo "Step2 - install and config apache"
yum -y install httpd
systemctl status httpd.service
systemctl start httpd.service
systemctl enable httpd # Kich hoat khoi dong cung he thong

echo "Step3 - Config needed and disable php5"
yum -y install epel-release
yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --disable remi-php54
yum-config-manager --enable remi-php72

echo "Step4 - Install PHP"
yum install php php-pear php-cgi php-common php-mbstring php-snmp php-gd php-pecl-mysql php-xml php-mysql php-gettext php-bcmath
echo "Edit file php.ini"
# -i thay the noi ung ngay file goc
# Neu co loi , kiem tra file /etc/php.ini
echo "date.timezone = Asia/Ho_Chi_Minh"
echo "max_execution_time = 300"
echo "memory_limit = 128M"
echo "post_max_size = 16M"
echo "upload_max_filesize = 2M"
echo "max_input_time = 300"
 
sed -i 's/;date\.timezone =/date\.timezone = Asia\/Ho_Chi_Minh #/' /root/etc/php.ini 
#sed -i 's/;date.timezone =/date.timezone = Asia\/Ho_Chi_Minh/' /root/linux/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /root/linux/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 128M/' /root/linux/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 16M/' /root/linux/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize  = 2M/' /root/linux/php.ini
sed -i 's/max_input_time = 60/max_input_time = 300/' /root/linux/php.ini

echo "Install MariaDB"
yum --enablerepo=remi install mariadb-server
systemctl start mariadb.service
systemctl enable mariadb
echo "Add a new root password: lam theo huong dan" 
mysql_secure_installation

echo "Step6 - Create database for zabbix"
echo "Please enter root password: "
read -p "-username: "  user
read -p "-passsword: "  passwd
read -p "-database: "  database
echo "Infor username and passsword of zabbix"
read -p "-zabbix user:" zabbixuser
read -p "-zabbix pass:" zabbixpass

mysql -u$user -p$passwd -e "create database $database character set utf8 collate utf8_bin;"
mysql -u$user -p$passwd -e "create user '$zabbixuser'@'localhost' identified BY '$zabbixpass';"
mysql -u$user -p$passwd -e "grant all privileges on $database.* to $zabbixuser@localhost ;"
mysql -u$user -p$passwd -e "flush privileges;"

echo "Step7 - Install Zabbix4.0"
rpm -ivh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
yum install zabbix-server-mysql  zabbix-web-mysql zabbix-agent zabbix-get

echo "Step8 - Configure Zabbix"
echo "Edit file /etc/httpd/conf.d/zabbix.conf"


sed -i 's/# php_value date.timezone /php_value date.timezone Asia\/Ho_Chi_Minh #/' /etc/httpd/conf.d/zabbix.conf
echo "Restart httpd service "
systemctl restart httpd.service
echo "Import MYSQL dump file "
echo "alert /usr/share/doc/zabbix-server-mysql-* kiem tra thu muc nay"
#cd /usr/share/doc/
#ls
#read -p "-Nhap thu muc zabbix-server-mysql-*: "  zabbixmysql
#cd /usr/share/doc/$zabbixmysql
cd /usr/share/doc/zabbix-server-mysql-4.0.12/
zcat create.sql.gz | mysql -u $zabbixuser -p $database

sed -i 's/# DBHost=/DBHost=localhost #/' /etc/zabbix/zabbix_server.conf
sed -i 's/# DBName=/DBName='$database' #/' /etc/zabbix/zabbix_server.conf
sed -i 's/# DBUser=/DBUser='$zabbixuser' #/' /etc/zabbix/zabbix_server.conf
sed -i 's/# DBPassword=/DBPassword='$zabbixpass' #/' /etc/zabbix/zabbix_server.conf

systemctl start zabbix-server.service
systemctl enable zabbix-server.service
echo "Modify firewall rule"
firewall-cmd --add-service={http,https} --permanent
firewall-cmd --add-port={10051/tcp,10050/tcp} --permanent
firewall-cmd --reload
systemctl restart httpd
echo "http://serverhost or IP/zabbix"
echo "admin/zabbix"
echo "Neu httpd restart khong duoc, kiem tra file /etc/httpd/conf.d/zabbix.conf line 20"
