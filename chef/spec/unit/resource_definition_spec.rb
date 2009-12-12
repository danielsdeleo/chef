#
# Author:: Adam Jacob (<adam@opscode.com>)
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

require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

describe Chef::ResourceDefinition do
  before(:each) do
    @def = Chef::ResourceDefinition.new()
  end
  
  describe "initialize" do
    it "should be a Chef::ResourceDefinition" do
      @def.should be_a_kind_of(Chef::ResourceDefinition)
    end
    
    it "should not initialize a new node if one is not provided" do
      @def.node.should eql(nil)
    end
    
    it "should accept a node as an argument" do
      node = Chef::Node.new
      node.name("bobo")
      @def = Chef::ResourceDefinition.new(node)
      @def.node.name.should == "bobo"
    end
  end
  
  describe "node" do
    it "should set the node with node=" do
      node = Chef::Node.new
      node.name("bobo")
      @def.node = node
      @def.node.name.should == "bobo"
    end
    
    it "should return the node" do
      @def.node = Chef::Node.new
      @def.node.should be_a_kind_of(Chef::Node)
    end
  end
  
  it "should accept a new definition with a symbol for a name" do
    lambda { 
      @def.define :smoke do 
      end
    }.should_not raise_error(ArgumentError)
    lambda { 
      @def.define "george washington" do
      end 
    }.should raise_error(ArgumentError)
    @def.name.should eql(:smoke)
  end
  
  it "should accept a new definition with a hash" do
    lambda { 
      @def.define :smoke, :cigar => "cuban", :cigarette => "marlboro" do
      end
    }.should_not raise_error(ArgumentError)
  end
  
  it "should expose the prototype hash params in the params hash" do
    @def.define :smoke, :cigar => "cuban", :cigarette => "marlboro" do; end
    @def.params[:cigar].should eql("cuban")
    @def.params[:cigarette].should eql("marlboro")
  end

  it "should store the block passed to define as a proc under recipe" do
    @def.define :smoke do
      "I am what I am"
    end
    @def.recipe.should be_a_kind_of(Proc)
    @def.recipe.call.should eql("I am what I am")
  end
  
  it "should set paramaters based on method_missing" do
    @def.mind "to fly"
    @def.params[:mind].should eql("to fly")
  end
  
  it "should raise an exception if prototype_params is not a hash" do
    lambda {
      @def.define :monkey, Array.new do
      end
    }.should raise_error(ArgumentError)
  end
  
  it "should raise an exception if define is called without a block" do
    lambda { 
      @def.define :monkey
    }.should raise_error(ArgumentError)
  end
  
  it "defines a method on RecipeDefinitionDSLCore for itself" do
    dsl_core = Chef::Mixin::RecipeDefinitionDSLCore
    dsl_core.should_receive(:add_definition_to_dsl).with(:metaprogramming_ftw)
    @def.define :metaprogramming_ftw do
      :noop
    end
  end
  
  it "stores itself as a prototype in the class" do
    @def.define :metaprogramming_ftw do
      :noop
    end
    Chef::ResourceDefinition.prototype_for(:metaprogramming_ftw).should == @def
  end
  
  it "should load a description from a file" do
    @def.from_file(File.join(File.dirname(__FILE__), "..", "data", "definitions", "test.rb"))
    @def.name.should eql(:rico_suave)
    @def.params[:rich].should eql("smooth")
  end  
  
  it "should turn itself into a string based on the name with to_s" do
    @def.name = :woot
    @def.to_s.should eql("woot")
  end
  
  describe "deep copying with #new" do
    
    it "dups itself and its params" do
      new_def = @def.new
      new_def.should_not equal(@def)
      new_def.params.should_not equal(@def)
      new_def.params.should == @def.params
    end
    
  end
  
  describe "handling resource definition prototypes" do
    
    it "stores resource definition prototypes in the class" do
      @def.name = :foobaz
      Chef::ResourceDefinition.add_prototype_for(@def)
      Chef::ResourceDefinition.prototype_for(:foobaz).should == @def
    end
    
    it "creates a new resource definition from a prototype" do
      @def.name   = :mew
      Chef::ResourceDefinition.add_prototype_for(@def)
      new_defn_block = lambda { snitch }
      new_defn = mock("cloned resource defn")
      new_defn.should_receive(:node=).with(:a_node)
      new_defn.should_receive(:snitch)
      @def.should_receive(:new).and_return(new_defn)
      result = Chef::ResourceDefinition.from_prototype(:mew, :a_node, &new_defn_block)
      result.should == new_defn
    end
    
  end
  
  describe "converting to a recipe" do
    it "takes the parameters for a recipe and creates one" do
      @def.name = :staying_fat
      snitch = nil
      @def.recipe = lambda { snitch = 4815162342 }
      new_defn = @def.new
      def_as_recipe = @def.to_recipe("delicious_foodz", :fat_kitteh, Chef::Node.new, nil)
      snitch.should == 4815162342
      def_as_recipe.params[:name].should == :fat_kitteh
      def_as_recipe.params.should == @def.params
    end
  end
  
end