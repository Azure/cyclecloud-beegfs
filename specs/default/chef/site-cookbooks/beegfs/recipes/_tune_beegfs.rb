# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
ruby_block "Tune TCP" do
    block do
      file = Chef::Util::FileEdit.new("/etc/sysctl.conf")
      file.insert_line_if_no_match("net.ipv4.neigh.default.gc_thresh1=1100", "net.ipv4.neigh.default.gc_thresh1=1100")
      file.insert_line_if_no_match("net.ipv4.neigh.default.gc_thresh2=2200", "net.ipv4.neigh.default.gc_thresh2=2200")
      file.insert_line_if_no_match("net.ipv4.neigh.default.gc_thresh4=4400", "net.ipv4.neigh.default.gc_thresh4=4400")
      file.write_file
    end
end