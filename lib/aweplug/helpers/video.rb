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
        uri_key = convert_url_to_key URI.parse(url)

        videos = site.videos || {} 
        site.send('videos=', videos) if site.videos.nil? # we'll need this later in the process
        if videos[uri_key]
          videos[uri_key].add_target_product product
        else
          @youtube ||= Aweplug::Helpers::Video::YouTube.new(site)
          @vimeo ||= Aweplug::Helpers::Video::Vimeo.new(site)
          videos[uri_key] = @vimeo.add(url, product: product, push_to_searchisko: push_to_searchisko)

          youtube_videos = @youtube.add(url, product: product, push_to_searchisko: push_to_searchisko)
          if youtube_videos
            youtube_videos.each do |v| 
              youtube_video_uri = URI.parse v.url
              youtube_video_uri.scheme = 'https' if youtube_video_uri.scheme == 'http'
              v.add_target_product product
              videos[youtube_video_uri.to_s.freeze] = v
            end
          end
          
          videos[uri_key].add_target_product(product) if (videos[uri_key] && product)
        end
        site.videos.merge! videos
        videos[uri_key]
      end

    end
  end
end

