check_root () {
	if (( $EUID == 0 )); then
		sub_main
	else
		echo "Please run this script by user root!"
		exit
	fi
}

install_apache () {
	echo "Install Apache..."
	sleep 1
	yum install httpd -y
	systemctl start httpd
	systemctl enable httpd

	# Mo cong HTTP(40) va HTTPS(443) vinh vien
	firewall-cmd --zone=public --permanent --add-service=http
	firewall-cmd --zone=public --permanent --add-service=https
	firewall-cmd --reload
	echo "Successfully Install Apache!"
	echo "Apache version"
	httpd -v
}

install_php () {
	echo "Install PHP..."
	sleep 1
	yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
	yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
	echo "Install PHP 7.2"
	sleep 1
	yum --enablerepo=remi-php72 install php -y
	yum --enablerepo=remi-php72 install php-xml php-soap php-xmlrpc php-mbstring php-json php-gd php-mcrypt php-mysql -y
	system restart httpd
	echo "PHP version"
	php -v
	sleep 1
	echo "Successfully Install PHP!"
}

config_virtual_host () {
	echo "Virtual Host Configuration"
	echo "Enter your domain: "
	read domain

	mkdir -p /var/www/$domain/html
	mkdir -p /var/www/$domain/log
	chown -R $USER:$USER /var/www/$domain/html
	chmod -R 755 /var/www

	echo "Enter text into web: "
	read webText
	echo "<h1>$webText</h1>" >> /var/www/$domain/html/index.html
	mkdir /etc/httpd/sites-available /etc/httpd/sites-enabled
    	echo "IncludeOptional sites-enabled/*.conf" >> /etc/httpd/conf/httpd.conf
    	echo "<VirtualHost *:80>" >> /etc/httpd/sites-available/$domain.conf
    	echo "ServerName www.$domain" >> /etc/httpd/sites-available/$domain.conf
    	echo "ServerAlias $domain" >> /etc/httpd/sites-available/$domain.conf
    	echo "DocumentRoot /var/www/$domain/html" >> /etc/httpd/sites-available/$domain.conf
    	echo "ErrorLog /var/www/$domain/log/error.log" >> /etc/httpd/sites-available/$domain.conf
    	echo "CustomLog /var/www/$domain/log/requests.log combined" >> /etc/httpd/sites-available/$domain.conf
    	echo "</VirtualHost>" >> /etc/httpd/sites-available/$domain.conf
    	ln -s /etc/httpd/sites-available/$domain.conf /etc/httpd/sites-enabled/$domain.conf
	
	# Fix loi restart service
	getenforce
	setenforce 0

	systemctl restart httpd
	ls -lZ /var/www/$domain/log
	echo "Enter IP domain: "
	read ip
	echo "$ip $domain" >> /etc/hosts
	echo "Successfully Configure Virtual Host!"
}

install_mariadb () {
	echo "Install MariaDB..."
	sleep 1
	yum install mariadb-server mariadb -y
	echo "character-set-server=utf8" >> /etc/my.cnf
	
	firewall-cmd --permanent --add-service=mysql
	firewall-cmd --reload
	
	systemctl start mariadb
	systemctl enable mariadb

	mysql_secure_installation
	echo "Successfully Install MariaDB!"
}

create_database () {
	echo "Create database and user"
	echo "Enter database name: "
	read db
	echo "Enter username: "
	read username
	echo "Enter password: "
	read password
	
	mysql -u root --password="123456" -e "create database $db;"
	mysql -u root --password="123456" -e "create user '$username'@'localhost' identified by '$password';"
	mysql -u root --password="123456" -e "grant all privileges on $db.* to '$username'@'localhost';"
}

install_wordpress () {
	install_apache
	install_php
	config_virtual_host
	install_mariadb
	create_database
	yum install wget -y
	wget http://wordpress.org/latest.tar.gz
	tar -xvf latest.tar.gz
	cp -rf wordpress/* /var/www/$domain/html/
	cd /var/www/
	chown -R apache:apache /var/www/$domain/html
	chcon -R --reference /var/www /var/www/$domain/html		
	echo "Successfully Install Wordpress!"
	cd /var/www/$domain/html
	sed -e "s/database_name_here/"$db"/" -e "s/username_here/"$username"/" -e "s/password_here/"$password"/" wp-config-sample.php > wp-config.php
}

sub_main () {
	install_wordpress
}

main () {
	check_root
}

main

exit
