#
# Author:: Joe Williams (<joe@joetify.com>)
# Copyright:: Copyright (c) 2009 Joe Williams
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
#

require 'chef/log'
require 'chef/mixin/command'
require 'chef/provider/base'

module Chef
  module Provider
    class Mdadm < Chef::Provider::Base

      include Chef::Mixin::Command

      def initialize(node, new_resource)
        super(node, new_resource)
      end

      def load_current_resource
        @current_resource = Chef::Resource::Mdadm.new(@new_resource.name)
        @current_resource.raid_device(@new_resource.raid_device)
        Chef::Log.debug("Checking for software raid device #{@current_resource.raid_device}")

        command = "mdadm --detail --scan"
        exists = false
        status = popen4(command) do |pid, stdin, stdout, stderr|
          stdout.each do |line|
            if line.include? @new_resource.raid_device
              exists = true
            end
          end
        end
        @current_resource.exists(exists)
      end

      def action_create
        unless @current_resource.exists
          command = "yes | mdadm --create #{@new_resource.raid_device} --chunk=#{@new_resource.chunk} --level #{@new_resource.level} --raid-devices #{@new_resource.devices.length} #{@new_resource.devices.collect{|x| x + " "}.to_s.chop}"
          Chef::Log.debug("mdadm command: #{command}")
          pid, stdin, stdout, stderr = popen4(command)
          Chef::Log.info("Created mdadm raid device (#{@new_resource.raid_device})")
          @new_resource.updated = true
        else
          Chef::Log.debug("mdadm raid device already exists (#{@new_resource.raid_device})")
        end
      end

      def action_assemble
        unless @current_resource.exists
          command = "yes | mdadm --assemble #{@new_resource.raid_device} #{@new_resource.devices.collect{|x| x + " "}.to_s.chop}"
          Chef::Log.debug("mdadm command: #{command}")
          pid, stdin, stdout, stderr = popen4(command)
          Chef::Log.info("Assembled mdadm raid device (#{@new_resource.raid_device})")
          @new_resource.updated = true
        else
          Chef::Log.debug("mdadm raid device already exists (#{@new_resource.raid_device})")
        end
      end

      def action_stop
        if @current_resource.exists
          command = "yes | mdadm --stop #{@new_resource.raid_device}"
          Chef::Log.debug("mdadm command: #{command}")
          pid, stdin, stdout, stderr = popen4(command)
          Chef::Log.info("Stopped mdadm raid device (#{@new_resource.raid_device})")
          @new_resource.updated = true
        else
          Chef::Log.debug("mdadm raid device doesn't exist (#{@new_resource.raid_device})")
        end
      end

    end
  end
end
