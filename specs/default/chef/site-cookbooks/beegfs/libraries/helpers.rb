# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
module BeeGFS
    class Helpers
        def self.search_for_manager(min_count=1, sleep_time=10, max_retries=6, &block)
            results = block.call
            retries = 0
            while results.length < min_count and retries < max_retries
              sleep sleep_time
              retries += 1
              results = block.call
              Chef::Log.info "Found #{results.length} nodes that match BeeGFS manager"
            end
            if retries >= max_retries
              raise Exception, "Timed out searching for BeeGFS manager"
            end
      
            results
          end
      
    end
end