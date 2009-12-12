#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Copyright:: Copyright (c) 2008, 2009 Opscode, Inc.
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

require 'chef/mixin/convert_to_class_name'
require 'chef/mixin/language'

class Chef
  module Mixin
    module RecipeDefinitionDSLCore
      
      include Chef::Mixin::Language
      extend Chef::Mixin::ConvertToClassName
      
      class << self
    
        def add_definition_to_dsl(name)
          method_body=<<-METHOD_BODY
          def #{name}(*args, &block)
            new_defn = Chef::ResourceDefinition.from_prototype(:#{name.to_s}, node, &block)
            new_defn.to_recipe(cookbook_name, args[0], node, collection)
          end
          METHOD_BODY
          module_eval(method_body)
        end
      
        def add_resource_to_dsl(resource_class)
          method_name = convert_to_snake_case(resource_class.name.to_s, "Chef::Resource")
          method_body =<<-RESOURCE_METHOD
          def #{method_name}(*args, &block)
            args << collection << node

            r = #{resource_class}.new(*args)
            set_enclosing_scope(r)
            r.load_prior_resource
            r.cookbook_name = cookbook_name
            r.recipe_name   = recipe_name
            r.params        = params
            r.instance_eval(&block) if block

            collection.insert(r)
            r
          end
          RESOURCE_METHOD

          module_eval(method_body)
        
        end
      end
      
      # This method may be overriden by classes including the module
      # to set enclosing scope on a newly created resource
      def set_enclosing_scope(new_resource)
      end
      
      def cookbook_name
        @cookbook_name ||= ""
      end
      
      def recipe_name
        @recipe_name ||= ""
      end
      
      def collection
        @collection ||= Chef::ResourceCollection.new
      end
      
      def node
        @node ||= nil
      end
      
      def params
        @params ||= {}
      end
      
      def method_missing(method_symbol, *args, &block)
        # Resource and resource definition lookups now happen
        # by dynamically defining methods on this module.
        # Log a helpful message and super, probably resulting in a 
        # NoMethodError or NameError
        Chef::Log.fatal "no resource or resource definition could be found for #{method_symbol}"
        super
      end
      
    end
  end
end
