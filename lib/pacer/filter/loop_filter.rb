module Pacer
  module Core
    module Route
      public

      def loop(&block)
        chain_route :looping_route => block
      end
    end
  end

  module Filter
    module LoopFilter
      def self.triggers
        [:looping_route]
      end

      attr_reader :looping_route

      def looping_route=(route)
        if route.is_a? Proc
          empty = Pacer::Route.new :filter => :empty, :back => self
          @looping_route = route.call(empty)
        else
          @looping_route = route
        end
      end

      def while(yield_paths = false, &block)
        @yield_paths = yield_paths
        @control_block = block
        self
      end

      protected

      def attach_pipe(end_pipe)
        unless @control_block
          raise 'No loop control block specified. Use either #while or #until after #loop.'
        end
        pipe = Pacer::Pipes::LoopPipe.new(graph, looping_pipe, @control_block)
        pipe.setStarts(end_pipe) if end_pipe
        pipe
      end

      def looping_pipe
        Pacer::Route.pipeline(looping_route)
      end

      def inspect_string
        "#{ inspect_class_name }(#{ @looping_route.inspect })"
      end
    end
  end
end
