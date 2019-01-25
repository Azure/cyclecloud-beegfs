# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
include_recipe "::default"


%w{grafana.repo influxdb.repo}.each do |repo_file|
  cookbook_file "/etc/yum.repos.d/#{repo_file}" do
      source repo_file
  end
end

execute 'install_graf_rpm' do
    command 'yum install -y https://dl.grafana.com/oss/release/grafana-5.4.2-1.x86_64.rpm'
    not_if 'rpm -qa | grep grafana-5.4.2-1.x86_64'
end

%w{beegfs-mon influxdb grafana}.each do |pkg|
    package pkg do
      not_if "rpm -qa | grep #{pkg}"
    end
  end

# manager_ipaddress = ::BeeGFS::Helpers.search_for_manager(node['cyclecloud']['cluster']['id'])
manager_ipaddress = node["beegfs"]["manager_ipaddress"]

chef_state =  node['cyclecloud']['chefstate']
beegfs_mon_conf_file = "/etc/beegfs/beegfs-mon.conf"
grafana_ini_file = "/etc/grafana/grafana.ini"

hostname_line = "sysMgmtdHost = #{manager_ipaddress}"

service "influxdb" do
    action [ :enable, :start ]
end

service "beegfs-mon" do
    action [:enable]
end

service "grafana-server" do
    action [ :enable, :start ]
end

ruby_block "Update #{beegfs_mon_conf_file}" do
    block do
      file = Chef::Util::FileEdit.new(beegfs_mon_conf_file)
      file.search_file_replace_line(/^sysMgmtdHost/, hostname_line)
      file.write_file
    end
    not_if "grep -q '#{hostname_line}' #{beegfs_mon_conf_file}"
    notifies :restart, 'service[beegfs-mon]', :immediately 
end

file "#{chef_state}/graf_dashboard.marker" do
    content 'intentionally blank'
    action :nothing
end

execute 'import_dashboards' do
    command "/opt/beegfs/scripts/grafana/import-dashboards default"
    creates "#{chef_state}/graf_dashboard.marker"
    returns [0,7]
    notifies :create, "file[#{chef_state}/graf_dashboard.marker]", :immediately
end


