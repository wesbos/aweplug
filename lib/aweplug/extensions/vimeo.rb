require 'aweplug/helpers/vimeo'
require 'aweplug/cache/yaml_file_cache'
require 'json'

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
        # layout              - Name of the layout to be used for the generated Pages.
        # push_to_searchisko  - A boolean controlling whether a push to
        #                       seachisko should happen. A push will not
        #                       happen when the development profile is in
        #                       use, regardless of the value of this 
        #                       option.
        #
        # Returns a new instance of this extension.                
        def initialize variable_name, layout, push_to_searchisko = true
          @variable = variable_name
          @layout = layout
          @push_to_searchisko = push_to_searchisko
        end

        def execute site 
          @site = site
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                         :authenticate => true, 
                                                         :searchisko_username => ENV['dcp_user'], 
                                                         :searchisko_password => ENV['dcp_password'], 
                                                         :cache => site.cache,
                                                         :logger => site.log_faraday})

          site[@variable].each do |url|
            id = url.match(/^.*\/(\d*)$/)[1] 
            page_path = Pathname.new(File.join 'video', 'vimeo', "#{id}.html")

            # Skip if the site already has this page
            next if site.pages.find {|p| p.source_path == page_path}

            page = ::Awestruct::Page.new(site,
                     ::Awestruct::Handlers::LayoutHandler.new(site,
                       ::Awestruct::Handlers::TiltHandler.new(site,
                         ::Aweplug::Handlers::SyntheticHandler.new(site, '', page_path))))
            page.layout = @layout
            page.output_path = File.join 'video', 'vimeo', id,'index.html'
            page.stale_output_callback = ->(page) { return (File.exist?(page.output_path) && File.mtime(__FILE__) > File.mtime(page.output_path)) }
            video = Aweplug::Helpers::Vimeo::Video.new url, access_token, site
            page.send('video=', video)
            page.send('video_url=', url)
            site.pages << page 
            
            unless (payload = video.searchisko_payload).nil?
              unless  !@push_to_searchisko || site.profile =~ /development/
                searchisko.push_content('vimeo', video.id, payload.to_json)
              end 
            end
          end
        end
      end
    end
  end
end
