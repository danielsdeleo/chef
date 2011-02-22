require 'chef/json_compat'

class Chef
  module DBModel

    module Persistor
      def self.included(including_class)
        including_class.extend(ClassMethods)
        create_scopes_on(including_class)
      end

      def self.create_scopes_on(including_class)
        including_class.scope(:names, :select => :name)
        including_class.scope(:by_name, lambda { |n| {:conditions => {:name => n}} })
      end

      module ClassMethods

        # Finds or initializes a persistence object from a domain object.
        def for(object, additional_attrs={})
          if persistence_obj = find(:first, :conditions => default_finder_for(object))
            persistence_obj.attributes = domain_object_to_attrs(object, additional_attrs)
          else
            persistence_obj = new(domain_object_to_attrs(object, additional_attrs))
          end
          persistence_obj.domain_object = object
          persistence_obj
        end

        def domain_object_to_attrs(object, additional_attrs={})
          attr_hash = explicit_columns.inject(additional_attrs) do |hsh, column_name|
            hsh[column_name] = object.send(column_name); hsh
          end
          attr_hash[:serialized_object] = Chef::JSONCompat.to_json(object)
          attr_hash
        end

        def default_finder_for(object)
          {name_column => object.send(name_column)}
        end

        def persists(domain_model_class)
          @domain_model_class = domain_model_class
        end

        # Set the column to use as the de-facto key. This should be indexed and
        # have a uniqueness constraint in the database.
        def use_name_column(name_column)
          @name_column = name_column
        end

        # The column used as the de-facto key. Defaults to <tt>:name</tt>
        def name_column
          @name_column || :name
        end

        # Gives the list of columns to be populated from the domain object when
        # creating/updating the DB Persistence object. See +columnize+
        def explicit_columns
          @explicit_columns ||= []
        end

        # Declare which fields of the domain object are given their own columns.
        # The object is stored in serialized (json) form in the
        # serialized_object column; the columns you add here are used in select
        # expressions, so make sure you put an index on them.
        def indexed_by(*explicit_columns)
          @explicit_columns = explicit_columns
        end

      end

      def update_from(updated_domain_object)
        update_attributes(self.class.domain_object_to_attrs(updated_domain_object))
      end

      def update_from!(updated_domain_object)
        update_attributes!(self.class.domain_object_to_attrs(updated_domain_object))
      end

      attr_writer :domain_object

      def domain_object
        @domain_object ||= Chef::JSONCompat.from_json(serialized_object)
      end

    end

  end
end





