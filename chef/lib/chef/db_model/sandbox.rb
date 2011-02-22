class Chef
  module DBModel
    class Sandbox < ActiveRecord::Base
      include Persistor

      indexed_by :name

      def guid
        name
      end

    end
  end
end