#!/bin/bash
function print_color(){
    case $1 in
        "green") COLOR="\033[0;32m" ;;
        "red") COLOR="\033[0;31m" ;;
        "*") COLOR="\033[0m" ;;
    esac

    echo -e "${COLOR} $2 ${NC}"
}

print_color "green" "Installing firewalld..."

sudo yum install -y firewalld
sudo service firewalld start
sudo systemctl enable firewalld

is_firewalld_active=$(systemctl is-active firewalld)

if [ $is_firewalld_active = "active" ]
then
    print_color "green" "Firewalld Service is active"
else
    print_color "red" "FirewallD Service is not active"
    exit 1
fi

# Mariadb
print_color "green" "Installing Mariadb"
sudo yum install -y mariadb-server
sudo vi /etc/my.cnf
sudo service mariadb start
sudo systemctl enable mariadb

# Configure firewall for Database
print_color "green" "Configure firewall for Database"
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

# Configure Database

print_color "green" "Configuring DB..."
mysql -e "CREATE DATABASE ecomdb;"
mysql -e "CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Load inventory

print_color "green" "Loading inventory into DB..."
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;
INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF
mysql < db-load-script.sql

# Deploy and configure Web
print_color "green" "Configuring Web Server"
sudo yum install -y httpd php php-mysql

print_color "green" "Configuring firewall for Web"
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Start httpd
print_color "green" "Starting web"
sudo service httpd start
sudo systemctl enable httpd

# Download code
print_color "green" "Cloning GIT Repo"
sudo yum install -y git
git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# Update index
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

print_color "green" "All set."

