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
          @path = Pathname.new(File.join site.dir, 'synthetic', path)
        else
          @path = Pathname.new(File.join site.dir, 'synthetic', path.to_s)
        end
      end

      def input_mtime(page)
        @input_mtime
      end

      def rendered_content(context, with_layouts)
        @content
      end 

      def raw_content
        @content
      end

      def relative_source_path 
        # Copied from file_handler.rb in awestruct
        begin
          p = @path.relative_path_from( site.dir ) 
          if !! ( %r(^\.\.) =~ p.to_s )
            return nil 
          end
          r = File.join( '', p )
          return r
        rescue Exception=>e
          nil
        end
      end
    end
  end
end
