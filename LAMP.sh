#!/bin/bash

#######################################
# Print a given a message in color
# Arguments:
#   Color. eg: green, red
#######################################
function print_color(){
    case $1 in
        "green") COLOR="\033[0;32m" ;;
        "red") COLOR="\033[0;31m" ;;
        "*") COLOR="\033[0m" ;;
    esac

    echo -e "${COLOR} $2 ${NC}"
}
#######################################
# Check the status of a given service. Error and exit if not active
# Arguments:
#   Service name
#######################################
function check_service_status() {
    is_service_active=$(systemctl is-active $1)

    if [ $is_service_active = "active" ]
    then
        print_color "green" "$1 Service is active"
    else
        print_color "red" "$1 Service is not active"
        exit 1
    fi
}
#######################################
# Check the ports open
# Arguments:
#   Ports. eg: 80, 443
#######################################
function is_firewalld_rule_configured(){

    firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports)

if [[ $firewalld_ports = *$1* ]]
then
    print_color "green" "Port $1 configured"
else
    print_color "red" "Port $1 not configured"
    exit 1
fi
}
#######################################
# Check the item is present on the webpage
# Arguments:
#   Webpage
#   Items
#######################################
function check_item(){
    if [[ $1 = *$2* ]]
    then
        print_color "green" "Item $2 is present on the web page"
    else
        print_color "red" "Item $2 is not present on the web page"
    fi
}



print_color "green" "Installing firewalld..."

sudo yum install -y firewalld
sudo service firewalld start
sudo systemctl enable firewalld

check_service_status firewalld

# Mariadb
print_color "green" "Installing Mariadb"
sudo yum install -y mariadb-server
sudo vi /etc/my.cnf
sudo service mariadb start
sudo systemctl enable mariadb

check_service_status mariadb

# Configure firewall for Database
print_color "green" "Configure firewall for Database"
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports)

is_firewalld_rule_configured 3306

# Configure Database

print_color "green" "Configuring DB..."
sudo mysql -e "CREATE DATABASE ecomdb;"
sudo mysql -e "CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Load inventory

print_color "green" "Loading inventory into DB..."
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;
INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF
sudo mysql < db-load-script.sql

mysql_db_results=$(sudo mysql -e "use ecomdb; select * from products;")

if [[ $mysql_db_results = *Laptop* ]]
then
    print_color "green" "Inventory data loaded"
else
    print_color "red" "Inventory data not loaded"
    exit 1
fi

# Deploy and configure Web
print_color "green" "Configuring Web Server"
sudo yum install -y httpd php php-mysql

print_color "green" "Configuring firewall for Web"
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf


is_firewalld_rule_configured 80

# Start httpd
print_color "green" "Starting web"
sudo service httpd start
sudo systemctl enable httpd

check_service_status httpd

# Download code
print_color "green" "Cloning GIT Repo"
sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# Update index
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

print_color "green" "All set."

web_page=$(curl http://localhost)

for item in Laptop Dronve VR Watch
do
    check_item "$web_page" $item
done