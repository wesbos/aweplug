require 'nokogiri'
require 'aweplug/helpers/cdn'
require 'net/http'
require 'sass'

module Aweplug
  module Helpers
    module Resources

      REMOTE_PATH_PATTERN = /((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)/

      def self.local_path_pattern(base_url)
        /^#{base_url}\/{1,2}(.*)$/
      end

      class Resource

        def initialize(site)
          @site = site
        end

        @@cache = {}

        def resources(id, src)
          if @site.cdn_http_base
            if @@cache.key?(src)
              @@cache[src]
            else
              raw_content = ""
              content = ""
              @@cache[src] = ""
              items(src).each do |i|
                if i =~ Resources::local_path_pattern(@site.base_url)
                  raw_content << local_content($1)
                elsif i =~ Resources::REMOTE_PATH_PATTERN
                  content << remote_content(i)
                end
              end
              file_ext = ext
              if !raw_content.empty?
                if @site.minify
                  content << compress(raw_content)
                else
                  content << raw_content
                end
              end
              if !content.empty? 
                filename = Aweplug::Helpers::CDN.new(ctx_path).version(id, file_ext, content)
                @@cache[src] << tag("#{@site.cdn_http_base}/#{ctx_path}/#{filename}")
              end
            end
          else
            src
          end
        end
        
        def items(src)
        end
        
        def tag(src)
        end

        def compress(content)
        end

        def ext
        end

        def ctx_path
        end

        def local_content(src)
          @site.engine.load_site_page(src).rendered_content
        end

        def remote_content(src)
          Net::HTTP.get(URI.parse(src))
        end

        def compressor(input, compressor)
          output = compressor.compress input

          input_len = input.length
          output_len = output.length

          if input_len > output_len
            $LOG.debug " %d bytes -> %d bytes = %.1f%%" % [ input_len, output_len, 100 * output_len/input_len ] if $LOG.debug?
            output
          else
            $LOG.debug " no gain" if $LOG.debug?
            input
          end
        end

      end

      class Javascript < Resource
      
        CONTEXT_PATH = "javascripts"

        def items(src)
          Nokogiri::HTML(src).css("script").to_a.map{|i| i["src"]}
        end
        
        def tag(src)
          %Q{<script src='#{src}'></script>}
        end

        def compress(content)
          compressor(content, JSCompressor.new)
        end

        def ext
          ".js"
        end

        def ctx_path
          @site.javascripts_context_path || CONTEXT_PATH
        end

        alias :super_local_content :local_content
        alias :super_remote_content :remote_content

        def local_content(src)
          "/* Original File: #{src} */\n#{super_local_content(src)};"
        end

        def remote_content(src)
          "/* Original File: #{src} */\n#{super_remote_content(src)};"
        end


        private

        class JSCompressor
          def compress( input )
            # Require this late to prevent people doing devel needing to set up a JS runtime
            require 'uglifier'
            Uglifier.new(:mangle => false).compile(input)
          end
        end

      end

      class Stylesheet < Resource
      
        CONTEXT_PATH = "stylesheets"

        def items(src)
          Nokogiri::HTML(src).css("link[rel='stylesheet']").to_a.map{|i| i["href"]}
        end
        
        def tag(src)
          %Q{<link rel='stylesheet' type='text/css' href='#{src}'></link>}
        end

        def compress(content)
          # Compression is not supported at this level. Sass :compressed should be used
          content
        end

        def ext
          ".css"
        end

        alias :super_local_content :local_content

        def local_content(src)
          if File.exists? src
            super_local_content(src)
          else
            scss = src.gsub(/\.css$/, ".scss")
            if File.exists? scss
              super_local_content(scss)
            else
              raise "Unable to locate file for #{src}"
            end
         end
        end

        def ctx_path
          @site.stylesheets_context_path || CONTEXT_PATH
        end

      end

      class SingleResource

        IMG_EXT = ['.png', '.jpeg', '.jpg', '.gif']
        FONT_EXT = ['.otf', '.eot', '.svg', '.ttf', '.woff']

        
        def initialize(base_path, cdn_http_base)
          @base = base_path
          @cdn_http_base = cdn_http_base
        end

        def path(src_path)
          if src_path =~ Resources::REMOTE_PATH_PATTERN
            content = Net::HTTP.get(URI.parse(src_path))
            src = Pathname.new($4)
          else
            src  = Pathname.new(src_path)
            base = Pathname.new(@base)
            base = base.dirname if !File.directory? base
            abs = base.join(src)
            if File.exists? abs
              content = File.read(abs)
            else
              raise "Unable to read file from #{abs}"
            end
          end
          file_ext = src.extname
          id = src.to_s[0, src.to_s.length - file_ext.length].gsub(/[\/]/, "_").gsub(/^[\.]{1,2}/, "")
          ctx_path = ctx_path file_ext
          cdn_name = Aweplug::Helpers::CDN.new(ctx_path).version(id, file_ext, content)
          out = "#{@cdn_http_base}/#{ctx_path}/#{cdn_name}"
          out
        end

        def url(src_path)
          "url(#{path(src_path)})"
        end

        def ctx_path(ext)
          if FONT_EXT.include? ext
            "fonts"
          elsif IMG_EXT.include? ext
            "images"
          else
            "other"
          end
        end

      end

      # Public: Slim helper that captures the content of a block
      # This allows scripts to be compressed and placed on an external CDN automatically
      #
      # This currently only supports resoures loaded from #{site.base_url}
      #
      # Note that this helper is NOT tested outside of Slim
      def javascripts(id, &block)
        Javascript.new(site).resources(id, yield)
      end

      # Public: Slim helper that captures the content of a block
      # This allows stylesheets to be placed on an external CDN automatically.
      #
      # This currently only supports resources loaded from #{site.base_url}
      #
      # Note that this helper is NOT tested outside of Slim
      def stylesheets(id, &block)
        Stylesheet.new(site).resources(id, yield)
      end

      def cdn(src)
        if site.cdn_http_base
          if src =~ Resources::local_path_pattern(site.base_url)
            src = $1
          end
          SingleResource.new(site.dir, site.cdn_http_base).path(src)
        else
          src
        end
      end

    end
  end
end

module Sass::Script::Functions

  def cdn(src)
    if @options[:cdn_http_base]
      Sass::Script::String.new(Aweplug::Helpers::Resources::SingleResource.new(@options[:original_filename].to_s, @options[:cdn_http_base].to_s).url(unquote(src).to_s))
    else
      Sass::Script::String.new("url(#{src.to_s})")
    end
  end


  declare :cdn, [:src]
end

