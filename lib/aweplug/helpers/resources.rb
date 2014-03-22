require 'nokogiri'
require 'uglifier'
require 'aweplug/helpers/cdn'
require 'net/http'

module Aweplug
  module Helpers
    class Resource

      def initialize(site)
        @site = site
        raise "Must define site.cdn_http_base if site.cdn: true" if @site.cdn && !site.cdn_http_base
      end

      @@cache = {}

      def resources(id, src)
        if @site.cdn
          if @@cache.key?(src)
            @@cache[src]
          else
            raw_content = ""
            content = ""
            @@cache[src] = ""
            items(src).each do |i|
              if !i.empty? && i =~ /^#{@site.base_url}\/{1,2}(.*)$/
                raw_content << local_content($1)
              else
                puts "Loading content from #{i}"
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

      private

      class JSCompressor
        def compress( input )
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


    module Resources
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
    end
  end
end

