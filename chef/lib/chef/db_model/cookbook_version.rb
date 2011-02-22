require 'active_record'
require 'chef/db_model/persistable'

class Chef
  module DBModel
    class CookbookVersion < ActiveRecord::Base
      include Persistor

      scope(:with_name_and_version, :select => %w{id name version})
      scope(:by_version, lambda { |v| {:conditions => {:version => v}} })

      indexed_by :name, :version

      # Cookbook versions are a bit different in that they are unique by name
      # and version, compound key style.
      def self.default_finder_for(cb_version)
        {:name => cb_version.name, :version => cb_version.version}
      end

      def self.latest_by_name(name)
        by_name(name).all.sort.last
      end

      def self.with_version_by_name
        with_name_and_version.all.inject({}) do |by_name, cookbook_version|
          by_name[cookbook_version.name] ||= []
          by_name[cookbook_version.name] << cookbook_version.version
          by_name
        end
      end

      def <=>(other)
        return nil unless other.respond_to?(:name) && name == other.name
        return nil unless other.respond_to?(:version)
        version <=> other.version
      end

      def version
        Chef::Version.new(self[:version])
      end

    end
  end
end
