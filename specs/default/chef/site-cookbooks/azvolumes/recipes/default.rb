
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
return unless node['cyclecloud'].key?('mounts')

# Should never hit this, return if mounts is initialized.
return if node['cyclecloud']['mounts'].nil? || node['cyclecloud']['mounts'].empty?

ct = 10
node['cyclecloud']['mounts'].keys.each do |k|
    mount = node['cyclecloud']['mounts'][k]
    if ! (mount.key?('disabled') && mount['disabled'] && mount.key?('mdadm') && mount['mdadm'])
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
