require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'chef/db_model/node'

describe Chef::DBModel::Node do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter  => "mysql",
                                            :host     => "localhost",
                                            :username => "root",
                                            :database => "chef" )

    #ActiveRecord::Base.logger = Logger.new(STDERR)
  end


  before do
    @node = Chef::Node.new
    @node.name("charlie")
    @node.default["default_attr"] = "default_attr_value"
    @node.set["normal_attr"] = "normal_attr_value"
    @node.chef_environment("rspec")
  end

  it "uses :name as the name column" do
    Chef::DBModel::Node.name_column.should == :name
  end

  it "has explicit columns for :name and :chef_environment" do
    Chef::DBModel::Node.explicit_columns.should =~ [:name, :chef_environment]
  end

  it "converts a node to attributes for the persistence object" do
    node_hash = Chef::DBModel::Node.domain_object_to_attrs(@node)
    node_hash[:name].should == 'charlie'
    node_hash[:chef_environment].should == "rspec"
    node_hash[:serialized_object].should == @node.to_json
  end

  it "populates a model object with its data" do
    m = Chef::DBModel::Node.for(@node)
    m.should be_a_kind_of(ActiveRecord::Base)
    m.name.should == 'charlie'
    m.chef_environment.should == 'rspec'
    m.serialized_object.should == @node.to_json
  end

  it "scopes nodes by name" do
    pending
  end

end

