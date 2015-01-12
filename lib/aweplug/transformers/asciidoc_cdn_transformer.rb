require 'nokogiri'
require 'aweplug/helpers/cdn'
require 'awestruct/util/exception_helper' 

module Aweplug
  # Public: Awestruct transformers to modify pages after generation.
  module Transformer
    # Public: Look for images from asciidoc files and 'cdn-ify' them.
    class AsciidocCdnTransformer 
      def transform(site, page, content)
        if (!site.cdn_http_base.nil? && (is_asciidoc? page) && page.output_extension == '.html') 
          resource = ::Aweplug::Helpers::Resources::SingleResource.new site.dir, site.cdn_http_base, site.cdn_out_dir, site.minify, site.version 

          doc = Nokogiri::HTML(content)
          altered = false
          doc.css('img').each do |img|
            src = img['src'] 
            begin
              unless src.nil? || src.start_with?(site.cdn_http_base)
                img['src'] = resource.path(src)
                altered = true
              end
            rescue Exception => e
              Awestruct::ExceptionHelper.log_message "Error cdn-ifying img #{img}"
              Awestruct::ExceptionHelper.log_building_error e, page.source_path
              Awestruct::ExceptionHelper.html_error_report e, page.source_path
            end
          end
          content = doc.to_html if altered
        end
        content
      end

      private

      def is_asciidoc? page
        ext = File.extname page.source_path
        ext == '.adoc' || ext == '.ad' || ext == '.asciidoc'
      end 
    end
  end
end
