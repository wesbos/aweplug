require 'aweplug/helpers/video'
require 'json'
require 'parallel'

module Aweplug
  module Extensions
    # Public: Awestruct Extension which iterates over a site variable which 
    #         contains video URLs and creates pages out of them, also sends 
    #         the info over to a searchisko instance for indexing. This 
    #         makes use of the Aweplug::Helper::Searchisko class, please see 
    #         that class for more info on options and settings for Searchisko.
    class Video 
        
      include Aweplug::Helpers::Video

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
          add_video u, site, push_to_searchisko: @push_to_searchisko
        end
      end

    end

  end
end

