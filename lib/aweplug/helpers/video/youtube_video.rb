require 'aweplug/helpers/video/video_base'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/searchisko'
require 'ostruct'
require 'duration'
require 'active_support'

module Aweplug
  module Helpers
    module Video
      # Internal: Data object to hold and parse values from the Vimeo API.
      class YouTubeVideo < ::Aweplug::Helpers::Video::VideoBase
        include Aweplug::Helpers::SearchiskoSocial

        def initialize video, site
          super video['snippet'], site
          @id = video['id']
          @url = "http://www.youtube.com/v=#{@id}"
          @duration = Duration.new(video['contentDetails']['duration'])
          @thumb_url = @video["thumbnails"]["medium"]["url"]
          @cast = contributor_exclude.include?(@video['channelTitle']) ? [] : [ { :name => @video['channelTitle'] } ]
          @normalized_cast = @cast.collect { |c| normalize('contributor_profile_by_jbossdeveloper_quickstart_author', c[:name], @searchisko) }
          @modified_date = @published_date = DateTime.parse(@video['publishedAt'])
          @player = video['player']['embedHtml']
          @viewCount = video['statistics']['viewCount']
          @likeCount = video['statistics']['likeCount']
          @target_product = []
        end

        attr_reader :url, :id, :duration, :thumb_url, :cast, :modified_date, 
                    :published_date, :normalized_cast, :target_product

        def provider
          'youtube'
        end

        def contributor_exclude
          super + ['JBoss Developer']
        end

        def embed color, width, height
          %Q{<iframe id="ytplayer" type="text/html" width="#{width}" height="#{height}" src="//www.youtube.com/embed/#{id}?&origin=#{@site.base_url}&color=#{color}&modestbranding=1" frameborder="0"></iframe>}
        end

        def add_target_product product
          @target_product << product
        end
      end
    end
  end
end

