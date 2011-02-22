#
# Author:: Stephen Delano (<stephen@opscode.com>)
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2010, 2011 Opscode, Inc.
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

require 'chef/environment'
require 'chef/cookbook_version_selector'
require 'chef/db_model/environment'

class Environments < Application

  include Merb::CookbookVersionHelper

  provides :json

  before :authenticate_every
  before :is_admin, :only => [ :create, :update, :destroy ]

  # GET /environments
  def index
    environment_list = Chef::DBModel::Environment.names.all
    display(environment_list.inject({}) { |res, env| res[env.name] = absolute_url(:environment, env.name); res })
  end

  # GET /environments/:id
  def show
    unless environment = Chef::DBModel::Environment.by_name(params[:id]).first
      raise NotFound, "Cannot load environment #{params[:id]}"
    end
    self.content_type = :json
    environment.serialized_object
  end

  # POST /environments
  def create
    env = params["inflated_object"]
    db_object = Chef::DBModel::Environment.for(params["inflated_object"])
    raise Conflict, "Environment already exists" unless db_object.new_record?

    db_object.save!
    self.status = 201
    display({:uri => absolute_url(:environment, env.name)})
  end

  # PUT /environments/:id
  def update
    if params[:id] == "_default"
      raise MethodNotAllowed, "You cannot edit the _default environment"
    end

    db_object = Chef::DBModel::Environment.for(params['inflated_object'])
    self.status = db_object.new_record? ?  201 : 200
    db_object.save!

    self.content_type = :json
    db_object.serialized_object
  end

  # DELETE /environments/:id
  def destroy
    if params[:id] == "_default"
      raise MethodNotAllowed, "You cannot delete the _default environment"
    end

    unless env = Chef::DBModel::Environment.by_name(params[:id]).first
      raise NotFound, "Cannot load environment #{params[:id]}"
    end
    env.delete
    self.content_type = :json
    env.serialized_object
  end

  # GET /environments/:environment_id/cookbooks
  # returns data in the format of:
  # {"apache2" => {
  #     :url => "http://url",
  #     :versions => [{:url => "http://url/1.0.0", :version => "1.0.0"}, {:url => "http://url/0.0.1", :version=>"0.0.1"}]
  #   }
  # }
  def list_cookbooks
    unless @environment = Chef::DBModel::Environment.by_name(params[:environment_id]).first
      raise NotFound, "Cannot load environment #{params[:environment_id]}"
    end

    num_versions = num_versions!

    cookbook_urls = @environment.filtered_cookbook_versions.inject({}) do |res, (cookbook_name,versions)|
      versions.map!{|v| v.version.to_s}
      res[cookbook_name] = expand_cookbook_urls(cookbook_name, versions, num_versions)
      res
    end

    display(cookbook_urls)
  end

  # GET /environments/:environment_id/cookbooks/:cookbook_id
  # returns data in the format of:
  # {"apache2" => {
  #     :url => "http://url",
  #     :versions => [{:url => "http://url/1.0.0", :version => "1.0.0"}, {:url => "http://url/0.0.1", :version=>"0.0.1"}]
  #   }
  # }
  def cookbook
    cookbook_name = params[:cookbook_id]

    unless @environment = Chef::DBModel::Environment.by_name(params[:environment_id]).first
      raise NotFound, "Cannot load environment #{params[:environment_id]}"
    end
    filtered_cookbooks = @environment.filtered_cookbook_versions

    raise NotFound, "Cannot load cookbook #{cookbook_name}" unless filtered_cookbooks.has_key?(cookbook_name)
    versions = filtered_cookbooks[cookbook_name].map{|v| v.version.to_s}
    num_versions = num_versions!("all")
    display({ cookbook_name => expand_cookbook_urls(cookbook_name, versions, num_versions) })
  end

  # GET /environments/:environment/recipes
  def list_recipes
    display(Chef::Environment.filtered_recipe_list(params[:environment_id]))
  end

  # GET /environments/:environment_id/nodes
  def list_nodes
    node_list = Chef::DBModel::Node.names.by_env(params[:environment_id]).all
    display(node_list.inject({}) do |response,node|
      response[node.name] = absolute_url(:node, node.name)
      response
    end)
  end

  # GET /environments/:environment_id/roles/:role_id
  def role
    begin
      role = Chef::Role.cdb_load(params[:role_id])
    rescue Chef::Exceptions::CouchDBNotFound
      raise NotFound, "Cannot load role #{params[:role_id]}"
    end
    display("run_list" => role.env_run_lists[params[:environment_id]])
  end

  # TODO: convert to nonosql
  # POST /environments/:environment_id/cookbook_versions
  #
  # Take the given run_list and return the versions of cookbooks that would
  # be used after applying the constraints of the given environment.
  #
  # INPUT: 
  #  :run_list = an Array of String's, e.g.,
  #  ["recipe[apache2]", "recipe[runit]"]
  #
  # OUT:
  #  Hash of cookbook names cookbook manifest
  #
  # NOTE: This method is a POST, not because it's a mutator (it's idempotent),
  # but the run_list can likely exceed Merb's query string limit for GET
  # of 1024 characters.
  def cookbook_versions_for_run_list
    begin
      # not possible to be nil due to the route to get us to this API
      # endpoint
      environment_input = params[:environment_id]

      run_list_input = params[:run_list]
      raise BadRequest, "Missing param: run_list" unless run_list_input
      raise BadRequest, "Param run_list is not an Array: #{run_list_input.class}" unless run_list_input.is_a?(Array)

      # Convert the input array of strings to a RunList containing
      # RunListItem's.
      run_list = Chef::RunList.new
      run_list_input.each do |run_list_item_string|
        run_list << run_list_item_string
      end

      # Expand the run list in the scope of the specified environment.
      names_to_cookbook_version = Chef::CookbookVersionSelector.expand_to_cookbook_versions(run_list, environment_input)
    rescue Chef::Exceptions::CouchDBNotFound
      raise NotFound, "Cannot load environment #{params[:environment_id]}"
    rescue Chef::Exceptions::CookbookVersionSelection::InvalidRunListItems => e
      raise PreconditionFailed, e.to_json
    rescue Chef::Exceptions::CookbookVersionSelection::UnsatisfiableRunListItem => e
      raise PreconditionFailed, e.to_json
    end

    # Convert from
    #  name => CookbookVersion
    # to
    #  name => cookbook manifest
    # and display.
    display(names_to_cookbook_version.inject({}) do |res, (cookbook_name, cookbook_version)|
              res[cookbook_name] = cookbook_version.generate_manifest_with_urls {|opts| absolute_url(:cookbook_file, opts) }
              res
            end)
  end
end
