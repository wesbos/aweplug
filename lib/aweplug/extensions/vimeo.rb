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
          site.send("video_cache=", {})
          
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end

          # Iterate over the albums, call the vimeo endpoint
          # for each video in the response create page
          Parallel.each(site[@variable]["albums"], in_threads: 10) do |album|
            # TODO: do something about pagination, if / when we hit that issue
            albumJson = JSON.load(exec_method('vimeo.albums.getVideos', {album_id: album['id'], per_page: 50, full_response: 1, format: 'json'}))

            albumJson['videos']['video'].each do |videoJson|
              video = Aweplug::Helpers::Vimeo::VimeoVideo.new videoJson, site
              page_path = Pathname.new(File.join 'video', 'vimeo', "#{video.id}.html")

              # Skip if the site already has this page
              next if site.pages.find {|p| p.source_path == page_path} 

              add_video_to_site video, site

              send_video_to_searchisko video, site, album['product']
            end
          end

          Parallel.each(site[@variable]["videos"], in_threads: 40) do |videoUrl|
            id = videoUrl.split('http://vimeo.com/').last
            page_path = Pathname.new(File.join 'video', 'vimeo', "#{id}.html")
            # Skip if the site already has this page
            next if site.pages.find {|p| p.source_path == page_path} 

            videoJson = JSON.load(exec_method "vimeo.videos.getInfo", {format: 'json', video_id: id})['video'].first
            video = Aweplug::Helpers::Vimeo::VimeoVideo.new videoJson, site

            add_video_to_site video, site

            send_video_to_searchisko video, site
          end
        end

        def add_video_to_site video, site
          page_path = Pathname.new(File.join 'video', 'vimeo', "#{video.id}.html")
          page = ::Awestruct::Page.new(site,
                                       ::Awestruct::Handlers::LayoutHandler.new(site,
                                        ::Awestruct::Handlers::TiltHandler.new(site,
                                         ::Aweplug::Handlers::SyntheticHandler.new(site, '', page_path))))
          page.layout = @layout
          page.output_path = File.join 'video', 'vimeo', video.id,'index.html'
          page.stale_output_callback = ->(p) { return (File.exist?(p.output_path) && File.mtime(__FILE__) > File.mtime(p.output_path)) }
          page.send('title=', video.title)
          page.send('description=', video.description)
          page.send('video=', video)
          page.send('video_url=', video.url)
          site.video_cache[video.url] = video
          site.pages << page 
        end

        def send_video_to_searchisko video, site, product = nil
          unless (payload = video.searchisko_payload).nil?
            unless  !@push_to_searchisko || site.profile =~ /development/
              searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                             :authenticate => true, 
                                                             :searchisko_username => ENV['dcp_user'], 
                                                             :searchisko_password => ENV['dcp_password'], 
                                                             :cache => site.cache,
                                                             :logger => site.log_faraday,
                                                             :searchisko_warnings => site.searchisko_warnings})
              payload.merge!({target_product: product})
              searchisko.push_content('jbossdeveloper_vimeo', video.id, payload.to_json)
            end 
          end
        end
      end

    end
  end
end
