# wpinstall.sh
This is a bash script for installing Wordpress. This script will install the latest version of Wordpress. During the installation, you can create the MYSQL database, add and/or delete themes, add and/or delete plugins, install a set of automation scripts, removes default Wordpress pages and posts, set the file and directory permissions, create the NGINX site and activate it, and install Let's Encrypt SSL certificates.

Any of the config settings can be added to a file for quicker installations. The default file is: "/usr/local/sbin/wordpress/wpinstall.conf". Passwords can be saved in the config file but that is NOT recommended and USE at your own RISK. You have been warned! 

The script generates random alphanumeric passwords with a default length of 32 characters. Passwords can be modified and are not stored or saved. The admin user name and password that we used dureing the installation are displayed when the script finishes. The admin password is not stored, saved, or remembered, the password can not be recovered. Please save it in a secure password manager.

#Requires:
* wp-cli that has been renamed or linked to wp
* mysql (if you want the script to create the database automatically)

#Future

This script could use a couple of changes to make it more configurable.
* Able to change webserver user from www-data.
* Change Theme and Plugin to use lists of Themes and Plugins to add/delete.
* Add apache configuration
* Add additional databases
