require 'oauth'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/video/helpers'
require 'yaml'
require 'google/api_client'
require 'aweplug/helpers/video/youtube_video'
require 'aweplug/google_apis'

module Aweplug
  module Helpers
    module Video
      class YouTube
        include Aweplug::Helpers::Video::Helpers
        include Aweplug::GoogleAPIs

        YOUTUBE_URL_PATTERN = /^https?:\/\/(www\.)?youtube\.com\/(watch|playlist)\?(list=|v=)([\w-]*)$/

        # This OAuth 2.0 access scope allows for full read/write access to the
        # authenticated user's account.
        YOUTUBE_API_SERVICE_NAME = 'youtube'
        YOUTUBE_API_VERSION = 'v3'

        attr_reader :youtube

        def initialize site
          @site = site
          @client = google_client(site)
          @youtube = @client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
        end

        def add(url, product: nil, push_to_searchisko: true)
          if url =~ YOUTUBE_URL_PATTERN
            videos = []
            if $2 == 'playlist'
              json = JSON.load(@client.execute!(
                :api_method => @youtube.playlist_items.list,
                :parameters => {
                  :playlistId => $4,
                  :part => 'id, snippet'
                }
              ).body)
              json['items'].each do |v|
                if v['contentDetails'].nil?
                  contentDetails = JSON.load(@client.execute!(
                    :api_method => @youtube.videos.list,
                    :parameters => {
                      :id => v['snippet']['resourceId']['videoId'],
                      :part => 'contentDetails'
                    }
                  ).body)
                  v.merge!(contentDetails['items'].first)
                end
              end
            else
              json = JSON.load(@client.execute!(
                :api_method => @youtube.videos.list,
                :parameters => {
                  :id => $4,
                  :part => 'snippet, contentDetails, id'
                }
              ).body)
            end
            json['items'].each do |v|
              if @site.videos["https://www.youtube.com/v=#{v['id']}"]
                video = @site.videos["https://www.youtube.com/v=#{v['id']}"]
                video.add_target_product product
                videos << video
              else
                videos << add_video(Aweplug::Helpers::Video::YouTubeVideo.new(v, @site), product, push_to_searchisko)
              end
            end
            videos
          end
        end

      end
    end
  end
end

