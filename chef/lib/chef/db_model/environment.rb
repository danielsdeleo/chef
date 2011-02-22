require 'chef/db_model/cookbook_version'

class Chef

  module DBModel
    class Environment < ActiveRecord::Base
      include Persistor

      indexed_by :name

      def self.create_default_environment
        unless by_name('_default').exists?
          env = Chef::Environment.new
          env.name '_default'
          env.description 'The default Chef environment'
          self.for(env).save!
        end
      end

      # Loads the set of Chef::CookbookVersion objects available to a given environment
      # === Returns
      # Hash
      # i.e.
      # {
      #   "coobook_name" => [ Chef::CookbookVersion ... ] ## the array of CookbookVersions is sorted highest to lowest
      # }
      def filtered_cookbook_versions
        cookbook_list = Chef::DBModel::CookbookVersion.all
        domain_object.filter_cookbook_versions(cookbook_list)
      end

      def filtered_recipe_list
        cookbook_list = Chef::DBModel::CookbookVersion.all
        filtered_versions = domain_object.filter_cookbook_versions(cookbook_list)
        filtered_versions.map do |cb_name, cb|
          cb.first.domain_object.recipe_filenames_by_name.keys.map do |recipe|
            case recipe
            when DEFAULT
              cb_name
            else
              "#{cb_name}::#{recipe}"
            end
          end
        end.flatten
      end

    end
  end


  # Add some methods to Chef::Environment that require hitting the database
  class Environment

    def version_constraints
      cookbook_versions.inject({}) {|res, (k,v)| res[k] = Chef::VersionConstraint.new(v); res}
    end

    def filter_cookbook_versions(cookbook_list)
      constraints = version_constraints
      filtered_list = cookbook_list.inject({}) do |res, cookbook|
        # FIXME: should cookbook.version return a Chef::Version?
        version               = cookbook.version
        requirement_satisfied = constraints.has_key?(cookbook.name) ? constraints[cookbook.name].include?(version) : true
        res[cookbook.name]    = (res[cookbook.name] || []) << cookbook if requirement_satisfied
        res
      end

      filtered_list.inject({}) do |res, (cookbook_name, versions)|
        res[cookbook_name] = versions.sort.reverse
        res
      end
    end

  end
end