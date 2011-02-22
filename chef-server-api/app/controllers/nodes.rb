#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
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

require 'chef/node'
require 'chef/environment'
require 'chef/db_model/node'
require 'chef/db_model/environment'
require 'chef/version_class'
require 'chef/version_constraint'
require 'chef/cookbook_version_selector'

class Nodes < Application

  provides :json

  before :authenticate_every
  before :admin_or_requesting_node, :only => [ :update, :destroy, :cookbooks ]

  def index
    @node_list = Chef::DBModel::Node.select(:name).all
    display(@node_list.inject({}) do |response, node|
      response[node.name] = absolute_url(:node, node.name)
      response
    end)
  end

  def show
    unless @node = Chef::DBModel::Node.by_name(params[:id]).first
      raise NotFound, "Cannot load node #{params[:id]}"
    end
    self.content_type = :json
    @node.serialized_object
  end

  def create
    @node = params["inflated_object"]

    if Chef::DBModel::Node.by_name(@node.name).exists?
      raise Conflict, "Node #{@node.name} already exists"
    end

   Chef::DBModel::Node.for(@node).save!

    self.status = 201
    display({ :uri => absolute_url(:node, @node.name) })
  end


  def update
    @node = params["inflated_object"]
    db_object = Chef::DBModel::Node.for(@node)
    self.status = db_object.new_record? ? 201 : 200
    db_object.save!
    display(@node)
  end

  def destroy
    unless @node = Chef::DBModel::Node.by_name(params[:id]).first
      raise NotFound, "Cannot load node #{params[:id]}"
    end

    @node.delete
    self.content_type = :json
    @node.serialized_object
  end

  # Return a hash, cookbook_name => cookbook manifest, of the cookbooks
  # appropriate for this node, using its run_list and environment.
  def cookbooks
    unless node = Chef::DBModel::Node.by_name(params[:id]).first
      raise NotFound, "Cannot load node #{params[:id]}"
    end
    @node = Chef::JSONCompat.from_json(node.serialized_object)

    # Get the mapping of cookbook_name => CookbookVersion applicable to
    # this node's run_list and its environment.
    display(load_all_files)
  end

  private

  def load_all_files
    unless @env = Chef::DBModel::Environment.by_name(@node.chef_environment).first
      raise NotFound, "The node #{params[:id]} belongs to an environment '#{@node.chef_environment}' that does not exist"
    end
    all_cookbooks = @env.filtered_cookbook_versions

    included_cookbooks = cookbooks_for_node(all_cookbooks)
    nodes_cookbooks = Hash.new
    included_cookbooks.each do |cookbook_name, cookbook|
      nodes_cookbooks[cookbook_name.to_s] = cookbook.generate_manifest_with_urls{|opts| absolute_url(:cookbook_file, opts) }
    end

    nodes_cookbooks
  end

  # returns name -> CookbookVersion for all cookbooks included on the given node.
  def cookbooks_for_node(all_cookbooks)
    # expand returns a RunListExpansion which contains recipes, default and override attrs [cb]
    # TODO: check for this on the client side before we make the http request [stephen 9/1/10]

    all_cookbooks = all_cookbooks.inject({}) do |versions_by_name, (name, version_db_objects)|
      versions_by_name[name] = version_db_objects.map(&:domain_object)
      versions_by_name
    end

    begin
      included_cookbooks = Chef::CookbookVersionSelector.expand_to_cookbook_versions(@node.run_list, @node.chef_environment)
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
    display(included_cookbooks.inject({}) do |acc, (cookbook_name, cookbook_version)|
              acc[cookbook_name.to_s] = cookbook_version.generate_manifest_with_urls{|opts| absolute_url(:cookbook_file, opts) }
              acc
            end)
  end

  # Accumulates transitive cookbook dependencies no more than once in included_cookbooks
  #   included_cookbooks == hash of name -> CookbookVersion, which is used for returning
  #                         result as well as for tracking which cookbooks we've already
  #                         recursed into
  #   all_cookbooks      == hash of name -> [ CookbookVersion ... ] , all cookbooks available, sorted by version number
  #   recipe             == hash of :name => recipe_name, :version => recipe_version to include
  #   parent_name        == the name of the parent cookbook (or run_list), for reporting broken dependencies
  def expand_cookbook_deps(included_cookbooks, all_cookbooks, recipe, parent_name)
    # determine the recipe's parent cookbook, which might be the
    # recipe name in the default case
    cookbook_name = (recipe[:name][/^(.+)::/, 1] || recipe[:name])
    if recipe[:version]
      version = Chef::Version.new(recipe[:version])
      Chef::Log.debug "Node requires #{cookbook_name} at version #{version}"
      # detect the correct cookbook version from the list of available cookbook versions
      cookbook = all_cookbooks[cookbook_name].detect { |cb| Chef::Version.new(cb.version) == version }
    else
      Chef::Log.debug "Node requires #{cookbook_name} at latest version"
      cookbook_versions = all_cookbooks[cookbook_name]
      Chef::Log.debug { "Available versions of cookbook #{cookbook_name}: [#{Array(cookbook_versions).map {|v| v.version}.join(',')}]" }
      # Chef::Environment.filtered_cookbook_versions returns cookbooks in DESCENDING order
      # so the newest one is the FIRST one.
      cookbook = cookbook_versions ? all_cookbooks[cookbook_name].first : nil
    end
    unless cookbook
      msg = "#{parent_name} depends on cookbook #{cookbook_name} #{version}, which is not available to this node"
      raise PreconditionFailed, msg
    end

    # we can't load more than one version of the same cookbook
    if included_cookbooks[cookbook_name]
      a = Chef::Version.new(included_cookbooks[cookbook_name].version)
      b = Chef::Version.new(cookbook.version)
      raise PreconditionFailed, "Conflict: Node requires cookbook #{cookbook_name} at versions #{a.to_s} and #{b.to_s}" if a != b
    else
      included_cookbooks[cookbook_name] = cookbook
    end

    # TODO:
    # In the past, we have ignored the version constraints from dependency metadata.
    # We will continue to do so for the time being, until the Gem::Version
    # sytax for the environments feature is replaced with something more permanent
    # [stephen 9/1/10]
    cookbook.metadata.dependencies.each do |dependency_name, dependency_version_constraints|
      Chef::Log.debug [included_cookbooks, all_cookbooks, dependency_name, "Cookbook #{cookbook_name}"].join(", ")
      recipe = {:name => dependency_name, :version => nil}
      expand_cookbook_deps(included_cookbooks, all_cookbooks, recipe, "Cookbook #{cookbook_name}")
    end
  end
end
