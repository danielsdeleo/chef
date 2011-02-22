require 'active_record'
require 'chef/db_model/persistable'

class Chef
  module DBModel
    class Node < ActiveRecord::Base
      include Persistor

      scope(:by_env, lambda { |e| {:conditions => {:chef_environment => e}} })
      # These fields in the node get their own columns
      indexed_by :name, :chef_environment

      # TODO... handle inserting into the Solr index.
      # Right now, using basic autoinc integer keys.
      # swtiching to uuid keys would be the easiest transition

    end
  end
end
