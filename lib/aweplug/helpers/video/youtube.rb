require 'oauth'
require 'aweplug/cache/yaml_file_cache'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/video/helpers'
require 'yaml'
require 'google/api_client'
require 'aweplug/helpers/video/youtube_video'

module Aweplug
  module Helpers
    module Video
      class YouTube
        include Aweplug::Helpers::Video::Helpers

        YOUTUBE_URL_PATTERN = /^https?:\/\/(www\.)?youtube\.com\/(watch|playlist)\?(list=|v=)(\w*)$/

        # This OAuth 2.0 access scope allows for full read/write access to the
        # authenticated user's account.
        YOUTUBE_SCOPE = 'https://www.googleapis.com/auth/youtube.readonly'
        YOUTUBE_API_SERVICE_NAME = 'youtube'
        YOUTUBE_API_VERSION = 'v3'

        attr_reader :youtube

        def initialize site
          @site = site
          site.send('cache=', Aweplug::Cache::YamlFileCache.new) if site.cache.nil?
        end

        def add(url, product: nil, push_to_searchisko: true)
          if url =~ YOUTUBE_URL_PATTERN
            videos = []
            json = @site.cache.fetch(url) do
              @client ||= Google::APIClient.new :application_name => @site.application_name, :application_version => @site.application_version, :key => ENV['google_api_key'], :authorization => nil
              @youtube ||= @client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
              if $2 == 'playlist'
                r = JSON.load(@client.execute!(
                  :api_method => @youtube.playlist_items.list,
                  :parameters => {
                    :playlistId => $4,
                    :part => 'id, snippet'
                  }
                ).body)
               r['items'].each do |v|
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
                r
              else
                JSON.load(@client.execute!(
                  :api_method => @youtube.videos.list,
                  :parameters => {
                    :id => $4,
                    :part => 'snippet, contentDetails, id'
                  }
                ).body)
              end
            end
            json['items'].each do |v|
              videos << add_video(Aweplug::Helpers::Video::YouTubeVideo.new(v, @site), product, push_to_searchisko)
            end
            videos
          end
        end

      end
    end
  end
end

