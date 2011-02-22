#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Nuo Yan (<nuo@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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

require 'chef/api_client'

class Clients < Application
  provides :json

  before :authenticate_every
  before :is_admin, :only => [ :index, :update, :destroy ]
  before :is_admin_or_validator, :only => [ :create ]
  before :admin_or_requesting_node, :only => [ :show ]
  
  # GET /clients
  def index
    @list = Chef::DBModel::ApiClient.names.all
    display(@list.inject({}) { |result, client| result[client.name] = absolute_url(:client, :id => client.name); result })
  end

  # GET /clients/:id
  def show
    unless @client = Chef::DBModel::ApiClient.by_name(params[:id]).first
      raise NotFound, "Cannot load client #{params[:id]}"
    end
    self.content_type = :json
    @client.serialized_object
  end

  # POST /clients
  def create
    if Chef::DBModel::ApiClient.by_name(params[:name]).exists?
      raise Conflict, "Client #{params[:name]} already exists"
    end

    if params.has_key?(:inflated_object)
      params[:name] ||= params[:inflated_object].name
      # We can only get here if we're admin or the validator. Only
      # allow creating admin clients if we're already an admin.
      if @auth_user.admin
        params[:admin] ||= params[:inflated_object].admin
      else
        params[:admin] = false
      end
    end


    @client = Chef::ApiClient.new
    @client.name(params[:name])
    @client.admin(params[:admin]) if params[:admin]
    @client.create_keys
    Chef::DBModel::ApiClient.for(@client).save!
    
    self.status = 201
    headers['Location'] = absolute_url(:client, @client.name)
    display({ :uri => absolute_url(:client, @client.name), :private_key => @client.private_key })
  end

  # PUT /clients/:id
  def update
    unless Chef::DBModel::ApiClient.by_name(params[:id]).exists?
      raise NotFound, "Cannot load client #{params[:id]}"
    end

    if params.has_key?(:inflated_object)
      params[:private_key] ||= params[:inflated_object].private_key
      params[:admin] ||= params[:inflated_object].admin
    end

    @client = Chef::ApiClient.new
    @client.name(params[:id])
    
    @client.admin(params[:admin]) unless params[:admin].nil?

    results = { :name => @client.name, :admin => @client.admin }

    if params[:private_key] == true
      @client.create_keys
      results[:private_key] = @client.private_key
    end

    Chef::DBModel::ApiClient.for(@client).save!

    display(results)
  end

  # DELETE /clients/:id
  def destroy
    unless @client = Chef::DBModel::ApiClient.by_name(params[:id]).first
      raise NotFound, "Cannot load client #{params[:id]}"
    end
    @client.delete
    display({ :name => @client.name })
  end

end

