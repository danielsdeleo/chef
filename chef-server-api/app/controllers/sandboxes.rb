#
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
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

require 'pp'
require 'chef/sandbox'
require 'chef/db_model/sandbox'
require 'chef/checksum'
require 'chef/db_model/checksum'

# Sandboxes are used to upload files to the server (e.g., cookbook upload).
class Sandboxes < Application
  
  provides :json

  before :authenticate_every

  include Chef::Mixin::Checksum
  include Merb::TarballHelper
  
  def index
    couch_sandbox_list = Chef::DBModel::Sandbox.names.all
    
    sandbox_list = Hash.new
    couch_sandbox_list.each do |sandbox|
      sandbox_list[sandbox.guid] = absolute_url(:sandbox, :sandbox_id => sandbox.guid)
    end
    display sandbox_list
  end

  def show
    unless sandbox = Chef::DBModel::Sandbox.by_name(params[:sandbox_id]).first
      raise NotFound, "Cannot find a sandbox named #{params[:sandbox_id]}"
    end

    self.content_type = :json
    sandbox.serialized_object
  end
 
  def create
    checksums = params[:checksums]
    
    raise BadRequest, "missing required parameter: checksums" unless checksums
    raise BadRequest, "required parameter checksums is not a hash: #{checksums.class.name}" unless checksums.is_a?(Hash)

    new_sandbox = Chef::Sandbox.new
    result_checksums = Hash.new

    all_existing_checksums = Chef::DBModel::Checksum.checksums.all.inject({}) { |h,cksum| h[cksum.checksum] = 1; h }

    checksums.keys.each do |checksum|
      if all_existing_checksums[checksum]
        result_checksums[checksum] = {
          :needs_upload => false
        }
      else
        result_checksums[checksum] = {
          :url => absolute_url(:sandbox_checksum, :sandbox_id => new_sandbox.guid, :checksum => checksum),
          :needs_upload => true
        }
        new_sandbox.checksums << checksum
      end
    end

    FileUtils.mkdir_p(sandbox_location(new_sandbox.guid))
    
    db_object = Chef::DBModel::Sandbox.for(new_sandbox)
    db_object.save!

    # construct successful response
    self.status = 201
    location = absolute_url(:sandbox, :sandbox_id => new_sandbox.guid)
    headers['Location'] = location
    display 'uri' => location, 'checksums' => result_checksums, 'sandbox_id' => new_sandbox.guid
  end
  
  def upload_checksum
    sandbox_file = ChefServerApi::SandboxFile.new(self.request.env["rack.input"], params)
    raise BadRequest, sandbox_file.error  if sandbox_file.invalid_params?
    raise NotFound, sandbox_file.error    if sandbox_file.invalid_sandbox?
    raise BadRequest, sandbox_file.error  if sandbox_file.invalid_file?
    
    sandbox_file.commit_to(sandbox_checksum_location(sandbox_file.sandbox_id, sandbox_file.expected_checksum))
    
    url = absolute_url(:sandbox_checksum, sandbox_file.resource_params)
    result = { 'uri' => url }
    display result
  end
  
  def update
    # look up the sandbox by its guid
    db_object = Chef::DBModel::Sandbox.by_name(params[:sandbox_id]).first
    raise NotFound, "cannot find sandbox with guid #{sandbox_id}" unless db_object
    existing_sandbox = db_object.domain_object
    raise BadRequest, "cannot update sandbox #{sandbox_id}: already complete" if existing_sandbox.is_completed

    if params[:is_completed]
      existing_sandbox.is_completed = (params[:is_completed] == true)

      if existing_sandbox.is_completed
        # Check if files were uploaded to sandbox directory before we 
        # commit the sandbox. Fail if any weren't.
        existing_sandbox.checksums.each do |checksum|
          checksum_filename = sandbox_checksum_location(existing_sandbox.guid, checksum)
          if !File.exists?(checksum_filename)
            raise BadRequest, "cannot update sandbox #{params[:sandbox_id]}: checksum #{checksum} was not uploaded"
          end
        end
        
        # If we've gotten here all the files have been uploaded.
        # Track the steps to undo everything we've done. If any steps fail,
        # we will undo the successful steps that came before it
        begin
          undo_steps = Array.new
          existing_sandbox.checksums.each do |file_checksum|
            checksum_filename_in_sandbox = sandbox_checksum_location(existing_sandbox.guid, file_checksum)
            checksum = Chef::Checksum.new(file_checksum)

            checksum.commit_sandbox_file(checksum_filename_in_sandbox)
            Chef::DBModel::Checksum.for(checksum).save!
            
            undo_steps << proc { checksum.revert_sandbox_file_commit; Chef::DBModel::Checksum.for(checksum).delete }
          end
        rescue
          # undo the successful moves we did before
          Chef::Log.error("Sandbox finalization: got exception moving files, undoing previous changes: #{$!} -- #{$!.backtrace.join("\n")}")
          undo_steps.each do |undo_step|
            undo_step.call
          end
          raise
        end
        
      end
    end
    
    db_object.update_from!(existing_sandbox)

    self.content_type = :json
    db_object.serialized_object
  end
  
  def destroy
    raise NotFound, "Destroy not implemented"
  end
  
end

