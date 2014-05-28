require 'nokogiri'
require 'aweplug/helpers/cdn'


module Aweplug
  # Public: Awestruct transformers to modify pages after generation.
  module Transformer
    # Public: Look for images from asciidoc files and 'cdn-ify' them.
    class AsciidocCdnTransformer 
      def transform(site, page, input)
        if (!site.cdn_http_base.nil? && (is_asciidoc? page) && page.output_extension == '.html') 
          resource = ::Aweplug::Helpers::Resources::SingleResource.new site.dir, site.cdn_http_base, site.minify 

          doc = Nokogiri::HTML(input)
          doc.css('img').each do |img|
            src = img['src'] 
            unless src.start_with? site.cdn_http_base
              img['src'] = resource.path(src)
            end
          end
          doc.to_html
        else
          input
        end 
      end

      private

      def is_asciidoc? page
        ext = File.extname page.source_path
        ext == '.adoc' || ext == '.ad' || ext == '.asciidoc'
      end 
    end
  end
end
