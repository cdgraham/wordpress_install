#!/bin/bash
################################################################################
#
#    Script to create a standard wordpress site.
#
#       Name: wpinstall.sh
#
#       Author: Christopher Graham
#
#       Usage: wpinstall.sh
#
################################################################################
# Setup Defaults
typeset -A config # init array
config=( # set default values in config array
    [ROOTUSER]="root"
    [ROOTPASS]=""
    [DBHOST]="localhost"
    [DBPORT]=3306
    [ADMINUSER]=adminuser
    [ADMINEMAIL]=email@example.com
)

while read line
do
    if echo $line | grep -F = &>/dev/null
    then
        varname=$(echo "$line" | cut -d '=' -f 1)
        config[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
done < /usr/local/sbin/wordpress/wpinstall.conf

# Override any Global variables here
# Global default log file set in wpinstall.conf uncomment to override for individual scripts
#WP_LOG_FILE=/var/log/wordpress
PASSWORDLEN=32

WP="$(which wp)"
if [ -z "$WP" ]; then
    echo "Error: wp not found"
    exit 1
fi

# Clear screen
clear
printf "Install a new Wordpress Site\n"

# Password Length
read -e -p "Generated Password Length: " -i "$PASSWORDLEN" PASSWORDLEN
DBPASS=`tr -cd '[:alnum:]' < /dev/urandom | fold -w$PASSWORDLEN | head -n1`
ADMINPASS=`tr -cd '[:alnum:]' < /dev/urandom | fold -w$PASSWORDLEN | head -n1`
echo

# Get Wordpress Details
read -e -p "Wordpress Domain: " -i "$DOMAIN" DOMAIN
read -e -p "Wordpress Site Title: " -i "$SITETITLE" SITETITLE
read -e -p "Wordpress Admin User: " -i "${config[ADMINUSER]}" config[ADMINUSER]
read -e -p "Wordpress Admin Password: " -i "$ADMINPASS" ADMINPASS
read -e -p "Wordpress Admin Email: " -i "${config[ADMINEMAIL]}" config[ADMINEMAIL]
echo

LOCATION=/var/www/$DOMAIN/httpdocs
WWWURL=www.${DOMAIN}
SHORTDOMAIN=${DOMAIN:0:27}
DBNAME=${SHORTDOMAIN%%.*}_wp
DBUSER=${SHORTDOMAIN%%.*}_user
DBPREFIX=wp_`date |md5sum |head -c 8`_

# Create Directory
read -e -p "Website Install Location: " -i "$LOCATION" LOCATION
echo
[ ! -d $LOCATION ] && mkdir -p $LOCATION || :

# Create/Install Database
printf "Getting Database Parameters\n"
read -e -p "Database Host: " -i "${config[DBHOST]}" config[DBHOST]
read -e -p "Database Port: " -i "${config[DBPORT]}" config[DBPORT]
read -e -p "Database Name: " -i "$DBNAME" DBNAME
read -e -p "Database User: " -i "$DBUSER" DBUSER
read -e -p "Database Password: " -i "$DBPASS" DBPASS
echo

read -p "Create Database? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	printf "Creating Database\n"
	read -e -p "Root User: " -i "${config[ROOTUSER]}" config[ROOTUSER]
	read -e -p "Root Password: " -i "${config[ROOTPASS]}" config[ROOTPASS]
	
	mysql --user=${config[ROOTUSER]} --password=${config[ROOTPASS]} --host=${config[DBHOST]} --port=${config[DBPORT]} <<EOF
CREATE DATABASE $DBNAME;
CREATE USER '$DBUSER'@'%' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'%';
FLUSH PRIVILEGES;
EXIT
EOF
fi

if [[ $? -ne "0" ]]; then
	echo "MySQL error - Exiting"
	exit 2
fi

printf "Installing Wordpress\n"

cd $LOCATION

# Get latest wordpress software
wp --allow-root core download

# Configue wordpress 
wp --allow-root core config --dbname=$DBNAME --dbuser=$DBUSER --dbpass=$DBPASS --dbhost=${config[DBHOST]} --dbprefix=$DBPREFIX  --dbcharset=utf8mb4 --dbcollate=utf8mb4_unicode_520_ci

# Install wordpress
wp --allow-root core install --url=$WWWURL --title='"$SITETITLE"' --admin_user=${config[ADMINUSER]} --admin_password=$ADMINPASS --admin
_email=${config[ADMINEMAIL]}

# Install WP Admin Panel plugin
printf "Installing Wordpress plugins (and removing Hello Dolly)\n"
wp --allow-root plugin delete hello
wp --allow-root plugin install elementor --activate
wp --allow-root plugin install /usr/local/src/wordpress/elementor-pro.zip --activate
wp --allow-root plugin install wordfence --activate

printf "Installing Astra theme and removing standard ones\n"
themes=`ls -l $LOCATION/wp-content/themes | grep '^d' | awk '{print $9}'`

wp --allow-root theme install /usr/local/src/wordpress/Astra.zip --activate

for theme in $themes
do
	echo "Removing $theme theme\n"
	wp --allow-root theme delete $theme
done

printf "Removing Default posts and pages\n"
wp --allow-root post delete $(wp --allow-root post list --post_type='post' --format=ids)
wp --allow-root post delete $(wp --allow-root post list --post_type='page' --format=ids)

# Change owner
chown -R www-data:www-data *
# Files
find . -type f -exec chmod 644 {} +
# Directories
find . -type d -exec chmod 755 {} +
# wp-config.php
chmod 600 wp-config.php

# add the domain name to the local host file
#echo -e "127.0.0.1\t$" >> /etc/hosts

# Add this site to the automated scripts
read -p "Add Site to Automated Scripts? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	cd /usr/local/sbin/wordpress
	# Update all the sites files adding the new site
	for sites in `ls *.sites` ; do
		sed -i '/SITES=(/a \\t"'$DOMAIN'"' $sites;
	done
fi

# Add this site to Nginx
read -p "Add Site to Nginx? This will stop and start Nginx (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	# Go to the Nginx site config directory
	cd /etc/nginx/sites-available/

	# Copy the wordpress template to the url of the site
	cp wordpress-example.com $DOMAIN

	# Change the example.com url to the actual url
	sed -i 's/EXAMPLE.com/'$DOMAIN'/g' $DOMAIN

	# Enable the site
	ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

	# Reload Nginx to get SSL from Letsencrypt
	systemctl reload nginx

	#certbot certonly --standalone -d $DOMAIN -d WWWURL
	letsencrypt certonly --webroot --agree-tos --email ${config[ADMINEMAIL]} -w /var/www/letsencrypt -d $DOMAIN -d $WWWURL

	# Enable the Certificates
	sed -i 's/\#ssl_certificate/ssl_certificate/g' /etc/nginx/sites-enabled/$DOMAIN 
	sed -i 's/\#return/return/' /etc/nginx/sites-enabled/$DOMAIN 

	# Start Nginx to pick up new site
	systemctl reload nginx
fi

echo "Your Login details:"
echo "Wordpress Admin User: $ADMINUSER"
echo "Wordpress Admin Password: $ADMINPASS"
# End wordpress install
