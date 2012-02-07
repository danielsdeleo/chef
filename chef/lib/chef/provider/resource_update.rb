
class Chef
  class Provider

    # {
    #    "run_id" : "1000",
    #    "resource" : { 
    #         "type" : "file",
    #         "name" : "/etc/passwd", 
    #         "start_time" : "2012-01-09T08:15:30-05:00",
    #         "end_time" : "2012-01-09T08:15:30-05:00",
    #         "status" : "modified",
    #         "initial_state" : "exists", 
    #         "final_state" : "modified", 
    #         "before" : { 
    #              "group" : "root", 
    #              "owner" : "root",
    #              "checksum" : "xyz"
    #         },
    #         "after" : { 
    #              "group" : "root", 
    #              "owner" : "root",
    #              "checksum" : "abc"
    #         },
    #         "delta" : "escaped delta goes here"
    #    },
    #    "event_data" : "" 
    # }

    class ResourceUpdate

      attr_accessor :type
      attr_accessor :name
      attr_accessor :duration #ms
      attr_accessor :status
      attr_accessor :initial_state
      attr_accessor :final_state
      attr_accessor :initial_properties
      attr_accessor :final_properties
      attr_accessor :event_data # e.g., a diff.

      def initial_state_from_resource(current_resource)
        @initial_properties = current_resource.state
      end

      def updated_state_from_resource(new_resource)
        @final_properties = new_resource.state
      end

    end
  end
end



