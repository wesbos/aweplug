require 'awestruct/handlers/base_handler'
require 'pathname'

module Aweplug
  module Handlers
    class SyntheticHandler < Awestruct::Handlers::BaseHandler
      attr_reader :path

      def initialize site, content, path
        super(site)
        @content = content
        @input_mtime = DateTime.now.to_time

        case (path)
        when Pathname
          @path = path
        else
          @path = Pathname.new(path.to_s)
        end
      end

      def input_mtime(page)
        @input_mtime
      end

      def rendered_content(context, with_layouts)
        @content
      end 
    end
  end
end
