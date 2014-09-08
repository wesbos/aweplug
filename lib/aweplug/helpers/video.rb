require 'aweplug/cache/yaml_file_cache'
require 'aweplug/helpers/video/vimeo'
require 'aweplug/helpers/video/youtube'
require 'aweplug/helpers/video/helpers'

module Aweplug
  module Helpers
    module Video
      include Aweplug::Helpers::Video::Helpers

      # Public: Embeds videos from vimeo inside a div. Retrieves the title
      # and video cast from vimeo using the authenticated API.
      # TODO Builds follow links (blog, facebook, twitter, linkedin) for any
      # video cast, using the DCP .
      #
      # url - the URL of the vimeo page for the video to display
      #
      # Returns the html snippet
      # 
      def video_player(video, snippet = nil)
        render video, "video_player.html.slim", snippet
      end

      # Public: Embeds a vimeo video thumbnail into a web page. Retrieves the title
      # and video cast from vimeo using the authenticated API.
      #
      # url - the URL of the vimeo page for the video to display
      #
      # Returns the html snippet.
      def video_thumb(video, snippet = nil)
        render video, "video_thumb.html.slim", snippet
      end

      def video(url)
        add_video url, site
      end

      def add_video(url, site, product: nil, push_to_searchisko: true)
        @youtube ||= Aweplug::Helpers::Video::YouTube.new(site)
        @vimeo ||= Aweplug::Helpers::Video::Vimeo.new(site)
        videos = []
        videos << @vimeo.add(url, product: product, push_to_searchisko: push_to_searchisko)
        videos << @youtube.add(url, product: product, push_to_searchisko: push_to_searchisko)        
        videos = videos.flatten.reject { |v| v.nil? }
        videos.length > 1 ? videos : videos.first
      end

    end
  end
end

