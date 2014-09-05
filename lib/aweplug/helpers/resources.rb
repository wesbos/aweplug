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
      
        PNG_EXT = [ '.png' ]
        IMG_EXT = [ PNG_EXT, '.jpeg', '.jpg', '.gif' ].flatten
        FONT_EXT = [ '.otf', '.eot', '.svg', '.ttf', '.woff' ]
        JS_EXT = [ '.js' ]

      class JSCompressor
        def compress( input )
          # Require this late to prevent people doing devel needing to set up a JS runtime
          require 'uglifier'
          Uglifier.new(:mangle => false).compile(input)
        end
      end

      class Content
        def initialize raw, minify, ext
          @raw = raw
          @minify = minify
          @ext = ext
        end

        def read
          if @minify
            out = compress(@raw)
            raw_len = @raw.length
            out_len = out.length

            if raw_len > out_len
              puts " %d bytes -> %d bytes = %.1f%%" % [ raw_len, out_len, 100 * out_len/raw_len ] if $LOG.debug?
              out
            else
              puts " no gain" if $LOG.debug?
              @raw
            end
          else
            @raw
          end
        end

        def md5sum
          Digest::MD5.hexdigest(@raw)
        end

        def compress(raw)
          # Note that CSS compression is not supported at this level. Sass :compressed should be used        
          if Aweplug::Helpers::Resources::JS_EXT.include?(@ext)
            Aweplug::Helpers::Resources::JSCompressor.new.compress(raw)
          elsif Aweplug::Helpers::Resources::PNG_EXT.include?(@ext)
            Aweplug::Helpers::PNG.new(raw).compress.output
          else
            raw
          end
        end

      end

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
                file_ext = ext
                cdn_file_path = Aweplug::Helpers::CDN.new(ctx_path, @site.cdn_out_dir, @site.cdn_version).add(id, file_ext, Content.new(content, @site.minify, file_ext))
                @@cache[src] << tag("#{@site.cdn_http_base}/#{cdn_file_path}")
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

      end

      class Javascript < Resource
      
        CONTEXT_PATH = "javascripts"

        def items(src)
          Nokogiri::HTML(src).css("script").to_a.map{|i| i["src"]}
        end
        
        def tag(src)
          %Q{<script src='#{src}'></script>}
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

      end

      class Stylesheet < Resource
      
        CONTEXT_PATH = "stylesheets"

        def items(src)
          Nokogiri::HTML(src).css("link[rel='stylesheet']").to_a.map{|i| i["href"]}
        end
        
        def tag(src)
          %Q{<link rel='stylesheet' type='text/css' href='#{src}'></link>}
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

        def initialize(base_path, cdn_http_base, cdn_out_dir, minify, version)
          @base = base_path
          @cdn_http_base = cdn_http_base
          @cdn_out_dir = cdn_out_dir
          @version = version
          @minify = minify
        end

        def path(src_path)
          if @cdn_http_base
            uri = URI.parse(src_path)
            file_ext = File.extname(uri.path)
            if uri.scheme
              raw_content = Net::HTTP.get(uri)
              id = uri.host.gsub(/\./, '_')
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
              id = ""
            end
            id << uri.path[0, uri.path.length - file_ext.length].gsub(/[\/]/, "_").gsub(/^[\.]{1,2}/, "")
            ctx_path = ctx_path file_ext
            cdn_file_path = Aweplug::Helpers::CDN.new(ctx_path, @cdn_out_dir, @version).add(id, file_ext, Content.new(raw_content, @minify, file_ext))
            res = URI.parse("#{@cdn_http_base}/#{cdn_file_path}")
            res.query = uri.query if uri.query
            res.fragment = uri.fragment if uri.fragment
            res
          else
            src_path
          end
        end

        def url(src_path)
          "url(#{path(src_path)})"
        end

        def ctx_path(ext)
          if Aweplug::Helpers::Resources::FONT_EXT.include? ext
            "fonts"
          elsif Aweplug::Helpers::Resources::IMG_EXT.include? ext
            "images"
          elsif Aweplug::Helpers::Resources::JS_EXT.include? ext
            "javascripts"
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
      def javascripts(id, deferred = false, &block)
        out = Javascript.new(site).resources(id, yield)
        if deferred
          @deferred_javascripts ||= {}
          @deferred_javascripts[id] = out
          page.extra_javascripts ||= []
          page.extra_javascripts << id
          ""
        else
          out
        end
      end

      def deferred_javascripts(id)
        @deferred_javascripts[id]
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
        site = site || @site
        if site.cdn_http_base
          if src =~ Resources::local_path_pattern(site.base_url)
            src = $1
          end
          SingleResource.new(site.dir, site.cdn_http_base, site.cdn_out_dir, site.minify, site.cdn_version).path(src)
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
      Sass::Script::String.new(Aweplug::Helpers::Resources::SingleResource.new(@options[:original_filename].to_s, @options[:cdn_http_base].to_s, @options[:cdn_out_dir].to_s, @options[:minify], @options[:cdn_version]).url(unquote(src).to_s))
    else
      Sass::Script::String.new("url(#{src.to_s})")
    end
  end


  declare :cdn, [:src]
end

