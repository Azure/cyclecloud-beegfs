# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
require 'chefspec'
require 'fauxhai'

RSpec.configure do |config|
  config.log_level = :error
  config.cookbook_path = ['../../cookbooks', '../../berks-cookbooks']
end

at_exit { ChefSpec::Coverage.report! }
