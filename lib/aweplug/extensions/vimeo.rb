require 'aweplug/helpers/vimeo'
require 'json'

module Aweplug
  module Extensions
    module Video
      # Public: Awestruct Extension which iterates over a site variable which 
      # contains vimeo URLs and creates pages out of them, also sends the info 
      # over to a searchisko instance for indexing.
      class Vimeo
        include Aweplug::Helpers::Vimeo

        # Public: Creates a new instance of this Awestruct plugin.
        #
        # variable_name - Name of the variable in the Awestruct Site containing
        #                 the list of vimeo videos.
        # layout        - Name of the layout to be used for the generated Pages.
        #
        # Returns a new instance of this extension.                
        def initialize variable_name, layout
          @variable = variable_name
          @layout = layout
        end

        def execute site 
          @site = site
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                         :authenticate => true, 
                                                         :searchisko_username => ENV['dcp_user'], 
                                                         :searchisko_password => ENV['dcp_password'], 
                                                         :logger => site.profile == 'developement'})

          site[@variable].each do |url|
            id = url.match(/^.*\/(\d*)$/)[1] 
            page_path = Pathname.new(File.join 'video', 'vimeo', "#{id}.html")
            page = ::Awestruct::Page.new(site,
                     ::Awestruct::Handlers::LayoutHandler.new(site,
                       ::Awestruct::Handlers::TiltHandler.new(site,
                         ::Aweplug::Handlers::SyntheticHandler.new(site, '', page_path))))
            page.layout = @layout
            page.output_path = File.join 'video', 'vimeo', id,'index.html'
            video = Aweplug::Helpers::Vimeo::Video.new url, access_token, site
            page.send('video=', video)
            page.send('video_url=', url)
            site.pages << page 

            unless video.fetch_info['title'].include? 'Unable to fetch'
              searchisko_payload = {
                :sys_type => 'jbossdeveloper_video',
                :sys_content_provider => 'jboss-developer',
                :sys_content_type => 'video',
                :sys_content_id => video.id,
                :sys_updated => video.modified_date,
                :sys_contributors => video.cast,
                :sys_activity_dates => [video.modified_date, video.upload_date],
                :sys_created => video.upload_date,
                :sys_title => video.title,
                :sys_url_view => "http://vimeo.com/#{video.id}",
                :sys_description => video.description,
                :duration => video.duration,
                :thumbnail => video.thumb_url,
                :tag => video.tags
              }

              unless site.profile =~ /development/
                searchisko.push_content(searchisko_payload[:sys_type], 
                  searchisko_payload[:sys_content_id], 
                  searchisko_payload.to_json)
              end 
            end
          end
        end
      end
    end
  end
end
