#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Copyright:: Copyright (c) 2008, 2009, 2010 Opscode, Inc.
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

require 'chef' / 'cookbook_loader'
require 'chef' / 'cookbook' / 'metadata'

class Cookbooks < Application
  
  provides :json

  before :authenticate_every
  before :params_helper
  
  attr_accessor :cookbook_name, :cookbook_version
  
  def params_helper
    self.cookbook_name = params[:cookbook_name]
    self.cookbook_version = params[:cookbook_version]
  end

  include Chef::Mixin::Checksum
  include Merb::TarballHelper
  
  def index
    cookbook_list = Chef::Cookbook.cdb_list
    response = Hash.new
    cookbook_list.each do |cookbook_name|
      cookbook_name =~ /^(.+)-(\d+\.\d+\.\d+)$/
      response[$1] = absolute_slice_url(:cookbook, :cookbook_name => $1)
    end
    display response 
  end

  def show_versions
    begin
      display Chef::Cookbook.cdb_by_version(cookbook_name)
    rescue ArgumentError => e
      raise NotFound, "Cannot find a cookbook named #{cookbook_name}"
    rescue Chef::Exceptions::CouchDBNotFound => e
      raise NotFound, "Cannot find a cookbook named #{cookbook_name}"
    end
  end

  def show
    cookbook = get_cookbook_version(cookbook_name, cookbook_version)
    display cookbook.generate_manifest_with_urls { |opts| absolute_slice_url(:cookbook_file, opts) }
  end

  def show_file
    cookbook = get_cookbook_version(cookbook_name, cookbook_version)
    
    checksum = params[:checksum]
    raise NotFound, "Cookbook #{cookbook_name} version #{cookbook_version} does not contain a file with checksum #{checksum}" unless cookbook.checksums.keys.include?(checksum)

    filename = checksum_location(checksum)
    raise InternalServerError, "File with checksum #{checksum} not found in the repository (this should not happen)" unless File.exists?(filename)

    send_file(filename)
  end

  def update
    raise(BadRequest, "You didn't pass me a valid object!") unless params.has_key?('inflated_object')
    raise(BadRequest, "You didn't pass me a Chef::Cookbook object!") unless params['inflated_object'].kind_of?(Chef::Cookbook)
    unless params["inflated_object"].name == cookbook_name
      raise(BadRequest, "You said the cookbook was named #{params['inflated_object'].name}, but the URL says it should be #{cookbook_name}.")
    end

    unless params["inflated_object"].version == cookbook_version
      raise(BadRequest, "You said the cookbook was version #{params['inflated_object'].version}, but the URL says it should be #{cookbook_version}.") 
    end
    
    # TODO: verify checksums in manifest are registered on the system [cw]

    begin
      cookbook = Chef::Cookbook.cdb_load(cookbook_name, cookbook_version)
      cookbook.manifest = params['inflated_object'].manifest
    rescue Chef::Exceptions::CouchDBNotFound => e
      Chef::Log.debug("Cookbook #{cookbook_name} version #{cookbook_version} does not exist")
      cookbook = params['inflated_object']
    end
    
    raise InternalServerError, "Error saving cookbook" unless cookbook.cdb_save

    display cookbook
  end
  
  def destroy
    begin
      cookbook = get_cookbook_version(cookbook_name, cookbook_version)
    rescue ArgumentError => e
      raise NotFound, "Cannot find a cookbook named #{cookbook_name} with version #{cookbook_version}"
    end

    display cookbook.cdb_destroy
  end

  private

  def get_cookbook_version(name, version)
    begin
      Chef::Cookbook.cdb_load(name, version)
    rescue Chef::Exceptions::CouchDBNotFound => e
      raise NotFound, "Cannot find a cookbook named #{name} with version #{version}"
    end
  end
  
end

