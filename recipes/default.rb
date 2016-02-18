#
# Cookbook Name:: caddy
# Recipe:: default
#
# Copyright 2015, computerlyrik, Christian Fischer
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Conventions
# caddy install dir at /usr/local/caddy
# log at /usr/local/caddy/caddy.log
# Caddyfile at /etc/Caddyfile
# pidfile at /var/run/caddy.pid

require 'chef/version_constraint'

ark 'caddy' do
  url "https://caddyserver.com/download/build?os=linux&arch=amd64&features=#{node['caddy']['features'].join(',')}"
  extension 'tar.gz'
  has_binaries ['./caddy']
  strip_components 0
  notifies :restart, 'service[caddy]'
end

execute 'setcap cap_net_bind_service=+ep caddy' do
  cwd '/usr/local/caddy'
  action :nothing
  subscribes :run, 'ark[caddy]', :immediately
end

template '/etc/Caddyfile' do
  variables ({ 'hosts' => node['caddy']['hosts'], 'document' => CaddyDocument.new })
  notifies :restart, 'service[caddy]'
end

variables = ({ :command => 'caddy',
               :options => "#{caddy_letsencrypt_arguments} -pidfile /var/run/caddy.pid -log /usr/local/caddy/caddy.log -conf /etc/Caddyfile" })

if %w(arch gentoo fedora suse).include? node['platform_family']
  is_systemd = true
elsif node['platform'] == 'ubuntu' && node['platform_version'] == '14.04'
  is_upstart = true
elsif node['platform_family'] == 'rhel' && Chef::VersionConstraint.new('>= 7.0.0').include?(node['platform_version'])
  is_systemd = true
else
  is_systemv = true
end

upstart = template '/etc/init/caddy.conf' do
  source 'upstart.erb'
  mode '0644'
  variables variables
  only_if { is_upstart }
end

systemv = template '/etc/init.d/caddy' do
  source 'sysv.erb'
  mode '0755'
  variables variables
  only_if { is_systemv }
end

systemd = template '/etc/systemd/system/caddy.service' do
  source 'systemd.erb'
  mode '0755'
  variables variables
  only_if { is_systemd }
end

service 'caddy' do
  action [:enable, :start]
  supports :status => true, :start => true, :stop => true, :restart => true
  subscribes :restart, systemd, :immediately
  subscribes :restart, upstart, :immediately
  subscribes :restart, systemv, :immediately
end
