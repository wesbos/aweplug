require 'aweplug/helpers/vimeo'
require 'aweplug/cache/yaml_file_cache'
require 'json'
require 'parallel'

module Aweplug
  module Extensions
    module Video
      # Public: Awestruct Extension which iterates over a site variable which 
      #         contains vimeo URLs and creates pages out of them, also sends 
      #         the info over to a searchisko instance for indexing. This 
      #         makes use of the Aweplug::Helper::Searchisko class, please see 
      #         that class for more info on options and settings for Searchisko.  
      class Vimeo
        include Aweplug::Helpers::Vimeo

        # Public: Creates a new instance of this Awestruct plugin.
        #
        # variable_name       - Name of the variable in the Awestruct Site containing
        #                       the list of vimeo videos.
        # push_to_searchisko  - A boolean controlling whether a push to
        #                       seachisko should happen. A push will not
        #                       happen when the development profile is in
        #                       use, regardless of the value of this 
        #                       option.
        #
        # Returns a new instance of this extension.                
        def initialize variable_name, push_to_searchisko = true
          @variable = variable_name
          @push_to_searchisko = push_to_searchisko
        end

        def execute site 
          Parallel.each(eval(@variable), in_threads: 40) do |u|
            add_vimeo_video url: u, site: site, push_to_searchisko: @push_to_searchisko
          end
        end

      end

    end
  end
end
