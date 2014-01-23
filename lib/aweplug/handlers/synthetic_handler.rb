require 'awestruct/handlers/base_handler'
require 'pathname'

module Aweplug
  # Public: Additional handlers for awestruct. Any handler here must extend 
  # Awestruct::Handlers::BaseHandler.
  module Handlers
    # Public: An awestruct handler used to create a page which has no file
    # backing it. 
    #
    # Examples
    #
    #   Aweplug::Handlers::SyntheticHandler(site, content, output_path)
    #   # => <Aweplug::Handlers::Synthetic:0x...>"
    class SyntheticHandler < Awestruct::Handlers::BaseHandler
      attr_reader :path

      # Public: Initializer for the handler.
      #
      # site    - awestruct Site object.
      # content - Content for the page, must respond to t_s.
      # path    - output Path or String location for the generated page.
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

      # Public: Returns the mtime for this instance
      #
      # page - Ignored, kept for compat with other handlers.
      #
      # Returns the Integer timestamp of when this object was created.
      def input_mtime(page)
        @input_mtime
      end

      # Public: Returns the rendered verison of @content.
      #
      # context      - Ignored, kept for compatibility.
      # with_layouts - Ignored, kept for compatibility.
      #
      # Returns @content.to_s.
      def rendered_content(context, with_layouts)
        @content.to_s
      end 

      # Public: Returns @content.to_s.
      #
      # Returns @content.to_s.
      def raw_content
        @content.to_s
      end

      # Public: Calculates and returns the path of @path relative to site.dir.
      #
      # Returns String path of @path calculated relative to site.dir. 
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
