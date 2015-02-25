require 'parallel'
require 'aweplug/helpers/drupal_service'

module Aweplug
  module Extensions
    class DrupalExtension 
      def execute site
        drupal = Aweplug::Helpers::DrupalService.default site 
        Parallel.each(site.pages, :in_threads => (site.build_threads || 0)) do |page|
          drupal.send_page page if page.output_extension.include? 'htm'
        end 
      end
    end
  end
end

