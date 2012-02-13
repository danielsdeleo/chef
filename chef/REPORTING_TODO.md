## Resource Status ##
Want to do: capture the state (and state transition) for something like
"file doesn't exist" -> "file created"

Example: File
exists, doesn't exist

Example: Service
two axes: enabled/disabled, running/not running.

Possible implementations:
1. Expose a "raw" array, providers modify it
2. zero or more boolean "attributes" (how service resource currently
   implemented)
3. zero or more pairs of methods, e.g.,

        @current_resource.enabled ; @current_resource.disabled
        @current_resource.running ; @current_resource.stopped

## Update Resources: Annotate State Attributes
Annotating Chef::Resource classes so we know which attributes describe
system state and which ones don't.

### TEST TODO ###
* scan_access_control

### Resources to Annotate ###
 * apt_package
 * bash
 * breakpoint
 * cookbook_file
 * cron
 * csh
 * deploy
 * deploy_revision
 * directory
 * dpkg_package
 * easy_install_package
 * env
 * erl_call
 * execute
 * file
 * freebsd_package
 * gem_package
 * git
 * group
 * http_request
 * ifconfig
 * link
 * log
 * macports_package
 * mdadm
 * mount
 * ohai
 * package
 * pacman_package
 * perl
 * portage_package
 * python
 * remote_directory
 * remote_file
 * route
 * rpm_package
 * ruby
 * ruby_block
 * scm
 * script
 * service
 * solaris_package
 * subversion
 * template
 * timestamped_deploy
 * user
 * yum_package


# NOTES

## Example Designs for Resource Attribute Definition

    class FileResource2 < Chef::Resource

      # Totally DSL

      state_attribute(:mode) do |a|
        a.desc = "Desired unix permissions of the file"
        a.validate do |value|
          unless value.kind_of?(String) or value.kind_of?(Integer)
            invalid!("invalid type blah blah")
          end
          # other stuff
        end
      end


      # Standard Rubyisms using method_added:

      state_attr
      desc "Desired unix permissions"
      validate do |value|
      # stuff
      end

      def mode(value=NULL)
        @mode = value unless value.equal?(NULL)
      end

      # Same as above, but for undocumented attributes:

      state_attr

      def mode(value=NULL)
        # blah blah
      end


      # Kinds of Resource Attributes
      # * id_attr: part of the resource's identity; usually the "name attribute"
      #   (always?); uniquely identifies the resource (given the type); ex: file's
      #   path, package's name, etc.
      # * state_attr: a modifiable property of the resource, like a file's permissions/owner/group/checksum
      # * others -- "modifier_attr" (?)
      #   ex:
      #     retry, ignore_failure, response_file (package), options (package)

      # Contrarily... what is the worse-is-better way to accomplish this?


      
    end

