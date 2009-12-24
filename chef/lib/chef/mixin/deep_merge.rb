#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'deep_merge'

module Chef
  module Mixin
    class DeepMerge
      def self.merge(first, second)
        first = Mash.new(first).to_hash unless second.kind_of?(Mash)
        first = first.to_hash
        second = Mash.new(second).to_hash unless second.kind_of?(Mash)
        second = second.to_hash

        Mash.new(first.ko_deep_merge!(second, {:knockout_prefix => '!merge:'}))
      end
    end
  end
end
