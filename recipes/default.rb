#
# Cookbook:: librenms
# Recipe:: default
#
# Copyright:: 2017, Armando Uch, All Rights Reserved.

execute 'set timezone system' do
    command "timedatectl set-timezone #{node['librenms']['phpini']['timezone']}"
end

package %w(mariadb-server mariadb epel-release)

service 'mariadb' do
  supports :status => true, :restart => true, :reload => true
  action [:start, :enable]
end

template '/tmp/create_db.sql' do
  source 'create_db.sql.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(:password => node['mariadb']['user_librenms']['password'])
end

execute 'create_db' do
  action :run
  command 'mysql -uroot < /tmp/create_db.sql'
  cwd '/tmp'
  user 'root'
  group 'root'
  not_if 'echo "show tables;" | mysql -uroot librenms'
end

template '/etc/my.cnf.d/extra-confs.cnf' do
  source 'extra-confs.cnf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[mariadb]'
end

execute 'Install-Repo-webtatic' do
  command 'rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm'
  action :run
  not_if 'yum repolist | grep -w webtatic'
end

package %w(composer cronie fping git ImageMagick jwhois mtr MySQL-python net-snmp
    net-snmp-utils nginx nmap php72w php72w-cli php72w-common php72w-curl php72w-fpm php72w-gd php72w-mbstring
    php72w-mysqlnd php72w-process php72w-snmp php72w-xml php72w-zip python-memcached rrdtool) do
  action :install
end

# bash 'install pear dependency' do
#   user 'root'
#   cwd '/tmp'
#   code <<-EOH
#   pear install Net_IPv4-1.3.4 && \
#   pear install Net_IPv6-1.2.2b2
#   EOH
#   not_if 'pear list | grep -wP "Net_IPv4|Net_IPv6"'
# end

template '/etc/php.d/myphp.ini' do
  source 'myphp.ini.erb'
  owner 'root'
  group 'root'
  variables(:timezone => node['librenms']['phpini']['timezone'])
  mode '0644'
end

service 'php-fpm' do
  supports :status => true, :restart => true, :reload => true
  action [:start, :enable]
end

execute 'remove old php config' do
  command 'mv www.conf www.conf.old'
  cwd '/etc/php-fpm.d'
  action :run
  only_if 'ls www.conf'
end

template '/etc/php-fpm.d/www-nginx.conf' do
  source 'www-nginx.conf.erb'
  owner 'root'
  group 'nginx'
  mode '0644'
  notifies :restart, 'service[php-fpm]'
end

bash 'dowload librenms' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    composer create-project --no-dev --keep-vcs librenms/librenms librenms dev-master
    EOH
    not_if 'ls /opt/librenms'
end

bash 'users librenms' do
    user 'root'
    cwd '/opt'
    code <<-EOH
    useradd librenms -d /opt/librenms -M -r
    usermod -a -G librenms nginx
    EOH
    not_if 'cat /etc/passwd | grep -wP "librenms"'
end

directory '/opt/librenms' do
  owner 'nginx'
  group 'nginx'
  mode '0755'
  action :create
end

bash 'post config librenms' do
  user 'root'
  cwd '/opt/librenms'
  code <<-EOH
  mkdir rrd logs && \
  chmod 775 rrd && \
  chown nginx:nginx rrd
  EOH
  not_if 'ls /opt/librenms | grep -wP "rrd|logs"'
end

service 'nginx' do
  supports :status => true, :restart => true, :reload => true
  action [:start, :enable]
end

template '/etc/nginx/conf.d/librenms.conf' do
  source 'librenms.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    :port => node['librenms']['port_service'],
    :hostname => node['librenms']['hostname']
    )
  notifies :restart, 'service[nginx]'
end

package 'policycoreutils-python' do
  action :install
end

bash 'set selinux for librenms' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?'
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?'
  restorecon -RFvv /opt/librenms/logs/
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?'
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?'
  restorecon -RFvv /opt/librenms/rrd/
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/storage(/.*)?'
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/storage(/.*)?'
  restorecon -RFvv /opt/librenms/storage/
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/bootstrap/cache(/.*)?'
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/bootstrap/cache(/.*)?'
  restorecon -RFvv /opt/librenms/bootstrap/cache/
  setsebool -P httpd_can_sendmail=1
  setsebool -P httpd_execmem 1
  EOH
  only_if 'sestatus | grep -w enforcing'
end

bash 'open ports' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  firewall-cmd --zone public --add-service http && \
  firewall-cmd --permanent --zone public --add-service http
  EOH
  only_if 'which firewall-cmd && firewall-cmd --state'
end

bash 'fix owner directory' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  chown nginx:nginx -R /var/lib/php
  chown nginx:nginx -R /opt/librenms
  EOH
end

service 'snmpd' do
  supports :status => true, :restart => true, :reload => true
  action [:enable]
end

template '/etc/snmp/snmpd.conf' do
  source 'snmpd.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    :randomstring => node['librenms']['snmp_random_string'],
    :webmaster => node['librenms']['webmaster'],
    :hostname => node['librenms']['hostname']
    )
  notifies :restart, 'service[snmpd]'
end

bash 'config snmp local' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
  chmod +x /usr/bin/distro
  EOH
  notifies :restart, 'service[snmpd]'
  not_if 'ls /usr/bin/distro'
end

template '/root/http_fping.tt' do
    source 'http_fping.tt.erb'
    owner 'root'
    group 'root'
    mode '0640'
end

bash 'load policy http_fping' do
    user 'root'
    cwd '/root'
    code <<-EOH
    checkmodule -M -m -o http_fping.mod http_fping.tt
    semodule_package -o http_fping.pp -m http_fping.mod
    semodule -i http_fping.pp
    EOH
    not_if 'ls /root/http_fping.pp'
end

execute 'create rotatelogs' do
  command 'cp misc/librenms.logrotate /etc/logrotate.d/librenms'
  cwd '/opt/librenms'
  action :run
  not_if 'ls /etc/logrotate.d/librenms'
end

execute 'create cron task' do
  command 'cp librenms.nonroot.cron /etc/cron.d/librenms'
  cwd '/opt/librenms'
  action :run
  not_if 'ls /etc/cron.d/librenms'
end

template '/opt/librenms/config.php' do
  source 'config.php.erb'
  owner 'nginx'
  group 'nginx'
  mode '0640'
  variables(
    :networks => node['librenms']['scanning_discovery'],
    :hostname => node['librenms']['hostname'],
    :port => node['librenms']['port_service'],
    :db_pass => node['mariadb']['user_librenms']['password']
    )
end

execute 'Build Database' do
  command 'php build-base.php'
  cwd '/opt/librenms'
  user 'root'
  action :run
end

execute 'Add user admin' do
  action :run
  command 'php adduser.php $LIBRE_USER $LIBRE_PASS 10 $LIBRE_MAIL'
  cwd '/opt/librenms'
  environment ({
    'LIBRE_USER' => node['librenms']['user_admin'],
    'LIBRE_PASS' => node['librenms']['user_pass'],
    'LIBRE_MAIL' => node['librenms']['webmaster']
    })
  user 'root'
  group 'root'
end
