require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'chef/db_model/checksum'

describe Chef::DBModel::Checksum do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter  => "mysql",
                                            :host     => "localhost",
                                            :username => "root",
                                            :database => "chef" )

    #ActiveRecord::Base.logger = Logger.new(STDERR)
  end

  before do
    @checksum_of_the_file = "3fafecfb15585ede6b840158cbc2f399"
    @checksum = Chef::Checksum.new(@checksum_of_the_file)
  end

  it "extracts attributes for the persistor" do
    attrs = Chef::DBModel::Checksum.domain_object_to_attrs(@checksum)
    attrs[:checksum].should == @checksum_of_the_file
    attrs[:serialized_object].should == @checksum.to_json
  end

  it "populates a peristence object with data from the checksum" do
    m = Chef::DBModel::Checksum.for(@checksum)
    m.checksum.should == @checksum_of_the_file
    m.serialized_object.should == @checksum.to_json
  end

end