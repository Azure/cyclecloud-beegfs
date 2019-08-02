
bootstrap=node['cyclecloud']['bootstrap']
bootstrap_dir="#{bootstrap}/volumes"

directory bootstrap_dir


%w(create-premium-array.sh create-nvme-array.sh ).each do |vol_file|
    cookbook_file "#{bootstrap_dir}/" + vol_file do
      source vol_file
      mode '0655'
    end
  end

# Return if mounts is undefined.
return unless node.key?('azvolumes') && node['azvolumes'].key?('mounts')

return if node['azvolumes']['mounts'].nil? || node['azvolumes']['mounts'].empty?

ct = 10
node['azvolumes']['mounts'].keys.each do |k|
    mount = node['azvolumes']['mounts'][k]
    if mount.key?('disabled') && mount['disabled'] 
        next
    end
    if k == "nvme"
        execute 'nvme_volume' do 
            user    'root'
            cwd     bootstrap_dir
            command "bash ./create-nvme-array.sh #{k} md#{ct}"
          end
    else
        execute "${k}_volume" do 
            user    'root'
            cwd     bootstrap_dir
            command "bash ./create-premium-array.sh #{k} md#{ct}"
          end
    end
    ct += 1
end
