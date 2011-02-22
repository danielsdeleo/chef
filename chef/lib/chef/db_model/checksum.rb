require 'active_record'
require 'chef/db_model/persistable'

class Chef
  module DBModel
    class Checksum < ActiveRecord::Base
      include Persistor
      indexed_by :checksum
      use_name_column :checksum

      scope(:by_checksum, lambda { |c| {:conditions => {:checksum => c}} })
      scope(:checksums, :select => :checksum)

      def purge
        domain_object.purge
        delete
      end

    end
  end
end