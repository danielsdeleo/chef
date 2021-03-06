#
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


require File.join(File.dirname(__FILE__), '..', '..', "spec_helper")

describe Chef::Util::FileEdit, "initialiize" do
  it "should create a new Chef::Util::FileEdit object" do
    Chef::Util::FileEdit.new("./spec/data/fileedit/hosts").should be_kind_of(Chef::Util::FileEdit)
  end
  
  it "should throw an exception if the input file does not exist" do
    lambda{Chef::Util::FileEdit.new("nonexistfile")}.should raise_error
  end

  it "should throw an exception if the input file is blank" do
    lambda{Chef::Util::FileEdit.new("./spec/data/fileedit/blank")}.should raise_error 
  end
  
end

describe Chef::Util::FileEdit, "search_file_replace" do
  
  it "should accept regex passed in as a string (not Regexp object) and replace the match if there is one" do
    helper_method("./spec/data/fileedit/hosts", "localhost", true)
  end
  

  it "should accept regex passed in as a Regexp object and replace the match if there is one" do
    helper_method("./spec/data/fileedit/hosts", /localhost/, true)
  end

  
  it "should do nothing if there isn't a match" do
    helper_method("./spec/data/fileedit/hosts", /pattern/, false)
  end

  
  def helper_method(filename, regex, value)
    fedit = Chef::Util::FileEdit.new(filename)
    fedit.search_file_replace(regex, "replacement")
    fedit.write_file
    (File.exist? filename+".old").should be(value)
    if value == true
      newfile = File.new(filename).readlines 
      newfile[0].should match(/replacement/)
      File.delete("./spec/data/fileedit/hosts")
      File.rename("./spec/data/fileedit/hosts.old", "./spec/data/fileedit/hosts")
    end
  end
  
end

describe Chef::Util::FileEdit, "search_file_replace_line" do

  it "should search for match and replace the whole line" do
    fedit = Chef::Util::FileEdit.new("./spec/data/fileedit/hosts")
    fedit.search_file_replace_line(/localhost/, "replacement line")
    fedit.write_file
    newfile = File.new("./spec/data/fileedit/hosts").readlines
    newfile[0].should match(/replacement/)
    newfile[0].should_not match(/127/)
    File.delete("./spec/data/fileedit/hosts")
    File.rename("./spec/data/fileedit/hosts.old", "./spec/data/fileedit/hosts")
  end
  
end

describe Chef::Util::FileEdit, "search_file_delete" do
  it "should search for match and delete the match" do
    fedit = Chef::Util::FileEdit.new("./spec/data/fileedit/hosts")
    fedit.search_file_delete(/localhost/)
    fedit.write_file
    newfile = File.new("./spec/data/fileedit/hosts").readlines
    newfile[0].should_not match(/localhost/)
    newfile[0].should match(/127/)
    File.delete("./spec/data/fileedit/hosts")
    File.rename("./spec/data/fileedit/hosts.old", "./spec/data/fileedit/hosts")
  end
end

describe Chef::Util::FileEdit, "search_file_delete_line" do
  it "should search for match and delete the matching line" do
    fedit = Chef::Util::FileEdit.new("./spec/data/fileedit/hosts")
    fedit.search_file_delete_line(/localhost/)
    fedit.write_file
    newfile = File.new("./spec/data/fileedit/hosts").readlines
    newfile[0].should_not match(/localhost/)
    newfile[0].should match(/broadcasthost/)
    File.delete("./spec/data/fileedit/hosts")
    File.rename("./spec/data/fileedit/hosts.old", "./spec/data/fileedit/hosts")
  end
end

describe Chef::Util::FileEdit, "insert_line_after_match" do
  it "should search for match and insert the given line after the matching line" do
    fedit = Chef::Util::FileEdit.new("./spec/data/fileedit/hosts")
    fedit.insert_line_after_match(/localhost/, "new line inserted")
    fedit.write_file
    newfile = File.new("./spec/data/fileedit/hosts").readlines
    newfile[1].should match(/new/)
    File.delete("./spec/data/fileedit/hosts")
    File.rename("./spec/data/fileedit/hosts.old", "./spec/data/fileedit/hosts")
  end
  
end






