require 'active_record'
require 'chef/db_model/persistable'
require 'chef/certificate'

class Chef
  module DBModel
    class ApiClient < ActiveRecord::Base
      include Persistor

      indexed_by :name

    end
  end
end
