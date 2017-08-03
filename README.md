# A chef recipe to deploy [LibreNMS](http://www.librenms.org/)

TODO: Instalation and configuration of [LibreNMS](http://www.librenms.org/)

- Only tested on Centos 7.x and RHEL
- The web administration page is in port 8080 by default
- Fully tested on SELinux. ___Your welcome ;)___
- This recipe is based on installation tutorial [RHEL/CentOS + Nginx](http://docs.librenms.org/Installation/Installation-CentOS-7-Nginx/)

## Install chef

You need to install chef to run this recipe.

	$ curl -L https://www.opscode.com/chef/install.sh | bash

> Login as __root__ user or use `sudo` instead

## How to deploy the CHEF recipe

Firstly move to **/var** directory and clone the chef project

	$ mkdir -p /var/chef/cookbooks
	$ cd /var/chef/cookbooks
	$ git clone https://github.com/jahrmando/librenms.git

> You will should have root privilege to clone in **/var** directory

Run librenms cookbook

	$ chef-solo -o 'recipe[librenms::default]'

> Before, check the __attributes/default.rb__ file to see what attributes to override
> if needed or use `sudo` instead

Atributes:

	default['mariadb']['user_librenms']['password'] = 'Ch4ng3me'

	default['librenms']['hostname'] = 'librenms.example.com'
	default['librenms']['port_service'] = '8080'
	default['librenms']['snmp_random_string'] = 'PaloCocinaPezCaosVerde'

	default['librenms']['webmaster'] = 'webmaster@example.com'
	default['librenms']['user_admin'] = 'administrator'
	default['librenms']['user_pass'] = 'Ch4ng3meT00'

	default['librenms']['phpini']['timezone'] = 'America/Mexico_City'

	default['librenms']['scanning_discovery'] = ['10.0.0.0/8', '192.168.0.0/16']

# Test with Kitchen

Yep, You can test it with [kitchen](http://kitchen.ci/).

	$ kitchen test default-centos-73

Tested on:

- CentOS 7.3

# Extra steps

Secure your MariaDB installation, please execute this:

	$ mysql_secure_installation
