require 'parallel'
require 'aweplug/helpers/video'
require 'aweplug/helpers/searchisko'
require 'json'

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
        Parallel.each(eval(@variable), :in_threads => (site.build_threads || 0)) do |u|
          (add_video u, site, push_to_searchisko: @push_to_searchisko) unless u.nil?
        end
        site.videos.reject! { |k,v| v.nil? }
        unless site.profile =~ /development/
          searchisko = Aweplug::Helpers::Searchisko.default site, 21600 # 6 hour default 

          vimeo_videos = site.videos.values.find_all {|v| v.url.include? 'vimeo'}.inject({}) do |h,v| 
            h[v.id] = v.searchisko_payload
            h
          end
          youtube_videos = site.videos.values.find_all {|v| v.url.include? 'youtube'}.inject({}) do |h,v| 
            h[v.id] = v.searchisko_payload
            h
          end
          searchisko.push_bulk_content "jbossdeveloper_vimeo", vimeo_videos
          searchisko.push_bulk_content "jbossdeveloper_youtube", youtube_videos
        end
      end

    end

  end
end

