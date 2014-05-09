require 'nokogiri'
require 'aweplug/helpers/cdn'
require 'aweplug/helpers/png'
require 'net/http'
require 'sass'
require 'tempfile'
require 'securerandom'

module Aweplug
  module Helpers
    module Resources

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
              content = ""
              @@cache[src] = ""
              items(src).each do |i|
                if i =~ Resources::local_path_pattern(@site.base_url)
                  content << local_content($1)
                elsif URI.parse(i).scheme
                  content << remote_content(i)
                end
              end
              if !content.empty?
                if @site.minify
                  content = compress(content)
                end
                file_ext = ext                
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
          scss = src.gsub(/\.css$/, ".scss")
          if File.exists? scss
            super_local_content(scss)
          elsif File.exists? src
            super_local_content(src)
          else
            raise "Unable to locate file for #{src}"
          end
        end

        def ctx_path
          @site.stylesheets_context_path || CONTEXT_PATH
        end

      end

      class SingleResource

        IMG_EXT = ['.png', '.jpeg', '.jpg', '.gif']
        FONT_EXT = ['.otf', '.eot', '.svg', '.ttf', '.woff']

        def initialize(base_path, cdn_http_base, minify)
          @base = base_path
          @cdn_http_base = cdn_http_base
          @minify = minify
        end

        def path(src_path)
          uri = URI.parse(src_path)
          file_ext = File.extname(uri.path)
          if uri.scheme
            content = Net::HTTP.get(uri)
          else
            # Some file paths may have query strings or fragments...
            base = Pathname.new(@base)
            base = base.dirname if !File.directory? base
            abs = base.join(uri.path)
            if File.exists? abs
              raw_content = File.read(abs)
            else
              raise "Unable to read file from #{abs}"
            end
            if @minify
              content = compress(raw_content, file_ext)
            else
              content = raw_content
            end
          end
          if @minify
            content = compress(content, file_ext)
          end
          id = uri.path[0, uri.path.length - file_ext.length].gsub(/[\/]/, "_").gsub(/^[\.]{1,2}/, "")
          ctx_path = ctx_path file_ext
          cdn_name = Aweplug::Helpers::CDN.new(ctx_path).version(id, file_ext, content)
          res = URI.parse("#{@cdn_http_base}/#{ctx_path}/#{cdn_name}")
          res.query = uri.query if uri.query
          res.fragment = uri.fragment if uri.fragment
          res
        end

        def compress(content, file_ext)
          if file_ext == ".png"
            Aweplug::Helpers::PNG.new(content).compress.output
          else
            content
          end
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
          SingleResource.new(site.dir, site.cdn_http_base, site.minify).path(src)
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
      Sass::Script::String.new(Aweplug::Helpers::Resources::SingleResource.new(@options[:original_filename].to_s, @options[:cdn_http_base].to_s, @options[:minify]).url(unquote(src).to_s))
    else
      Sass::Script::String.new("url(#{src.to_s})")
    end
  end


  declare :cdn, [:src]
end

