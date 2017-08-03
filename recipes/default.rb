#
# Cookbook:: librenms
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

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

package %w(php70w php70w-cli php70w-gd php70w-mysql php70w-snmp php70w-pear php70w-curl php70w-common php70w-fpm php70w-mcrypt) do
  action :install
end

package %w(nginx net-snmp ImageMagick jwhois nmap mtr rrdtool MySQL-python net-snmp-utils cronie fping git) do
  action :install
end

bash 'install pear dependency' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  pear install Net_IPv4-1.3.4 && \
  pear install Net_IPv6-1.2.2b2
  EOH
  not_if 'pear list | grep -wP "Net_IPv4|Net_IPv6"'
end

template '/etc/php.d/myphp.ini' do
  source 'myphp.ini.erb'
  owner 'root'
  group 'root'
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
  group 'root'
  mode '0644'
  notifies :restart, 'service[php-fpm]'
end

user 'librenms' do
  action :create
  comment 'Librenms User'
  home '/opt/librenms'
  shell '/bin/bash'
  password '$1$TepOZh6R$ImOmJMK2Jr7pZXUusU.Sx1'
end

bash 'add user groups' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  usermod -a -G librenms nginx && \
  usermod -a -G librenms apache
  EOH
  not_if 'grep librenms /etc/group | grep -wP "nginx|apache"'
end

directory '/opt/librenms' do
  owner 'nginx'
  group 'nginx'
  mode '0755'
  action :create
end

git '/opt/librenms' do
  repository 'https://github.com/librenms/librenms.git'
  reference 'master'
  user 'nginx'
  group 'nginx'
  action :sync
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
  variables(:hostname => node['librenms']['hostname'])
  notifies :restart, 'service[nginx]'
end

package 'policycoreutils-python' do
  action :install
end

bash 'set selinux for librenms' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?' && \
  semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?' && \
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?' && \
  semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?' && \
  restorecon -RFvv /opt/librenms/logs/ && \
  restorecon -RFvv /opt/librenms/rrd/ && \
  setsebool -P httpd_can_sendmail=1 && \
  setsebool -P httpd_execmem 1 && \
  setsebool -P httpd_unified 1
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
  only_if 'which firewall-cmd'
end

bash 'install something' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  chown :nginx -R /var/lib/php/
  EOH
end

template '/etc/snmp/snmpd.conf' do
  source 'snmpd.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    :randomstring => node['librenms']['snmp_random_string'],
    :webmaster => node['librenms']['webmaster']
    )
end

bash 'config snmp local' do
  user 'root'
  cwd '/tmp'
  code <<-EOH
  curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro && \
  chmod +x /usr/bin/distro
  EOH
end

service 'snmpd' do
  supports :status => true, :restart => true, :reload => true
  action [:restart, :enable]
end

execute 'create rotatelogs' do
  command 'cp misc/librenms.logrotate /etc/logrotate.d/librenms'
  cwd '/opt/librenms'
  action :run
end

execute 'create cron task' do
  command 'cp librenms.nonroot.cron /etc/cron.d/librenms'
  cwd '/opt/librenms'
  action :run
end
