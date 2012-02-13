
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

      attr_accessor :duration #ms
      attr_accessor :status
      attr_accessor :initial_state
      attr_accessor :final_state
      attr_accessor :initial_properties
      #attr_accessor :final_properties
      attr_accessor :event_data # e.g., a diff.

      def initialize(new_resource)
        @new_resource = new_resource
        @current_resource = nil
        @start_time, @end_time = nil, nil
        @result = nil
      end

      def type
        @new_resource.type
      end

      def name
        @new_resource.name
      end

      def run_action
        @start_time = Time.now
        yield
      rescue Exception => e
        @event_data = e
        @result = :failed
        raise
      else
        @result = :success
      ensure
        @end_time = Time.now
      end

      def initial_state_from_resource(current_resource)
        @current_resource = current_resource
        @initial_properties = current_resource.state
      end

      def final_properties
        @new_resource.state
      end

      def duration
        @end_time.to_f - @start_time.to_f
      end

      def display
        s=(<<-EOH)
#{@new_resource} #{status} in #{duration.round(4)}s
       status: (#{@current_resource.status} -> #{@new_resource.status})
initial state: #{initial_properties}
  final state: #{final_properties}
EOH
        s << "Change:\n#@event_data" if @event_data
        s
      end



    end
  end
end



