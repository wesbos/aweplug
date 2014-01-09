require 'oauth'

module Aweplug
  module Helpers
    module Vimeo

      # Public: Embeds videos from vimeo inside a div. Retrieves the title
      # and video cast from vimeo using the authenticated API.
      # TODO Builds follow links (blog, facebook, twitter, linkedin) for any
      # video cast, using the DCP .
      #
      # url - the URL of the vimeo page for the video to display
      #
      # Returns the html snippet
      # 
      def vimeo(url)
        id = video_id(url)
        title = video_title(id)
        out = %Q[<div class="embedded-media">] +
        %Q[<h4>#{title}</h4>] +
        %Q[<iframe src="//player.vimeo.com/video/#{id}\?title=0&byline=0&portrait=0&badge=0&color=2664A2" width="500" height="313" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen}></iframe>]
        cast = video_cast(id)
        cast.each do |c|
          out += %Q[<div class="follow-links">] +
          %Q[<span class="title">Follow #{first_name(c.realname)}</span>] +
          %Q[<a><i class="icon-rss"></i></a>] +
          %Q[<a><i class="icon-facebook"></i></a>] +
          %Q[<a><i class="icon-twitter"></i></a>] +
          %Q[<a><i class="icon-linkedin"></i></a>] +
          %Q[</div>]
        end
        out + %Q[</div>]
      end

      # Internal: Extracts a firstname from a full name
      #
      # full_name - the full name, e.g. Pete Muir
      def first_name(full_name)
        full_name.split[0]
      end

      # Internal: Extracts a Vimeo video id from a Vimeo video URL
      #
      # url - the url of the video
      def video_id(url)
        url.match(/^.*\/(\d*)$/)[1]
      end

      # Internal: Retrieves a video title using the Vimeo API
      #
      # video_id - the id of the video to fetch the title for
      def video_title(video_id)
        body = exec_method "vimeo.videos.getInfo", video_id
        if body 
          JSON.parse(body)["video"][0]["title"]
        else
          "Unable to fetch video info from vimeo"
        end
      end

      # Internal: Retrieves the cast of a video using the Vimeo API
      #
      # video_id - the id of the video to fetch the title for
      def video_cast(video_id)
        body = exec_method "vimeo.videos.getCast", video_id
        cast = []
        if body
          JSON.parse(body)["cast"]["member"].each do |c|
            cast << OpenStruct.new(c)
          end
        end
        cast
      end

      # Internal: Execute a method against the Vimeo API
      #
      # method - the API method to execute
      # video_id - the id of the video to execute the method for
      #
      # Returns JSON retreived from the Vimeo API
      def exec_method(method, video_id)
        if access_token
          query = "http://vimeo.com/api/rest/v2?method=#{method}&video_id=#{video_id}&format=json"
          access_token.get(query).body
        end
      end

      # Internal: Obtains an OAuth::AcccessToken for the Vimeo API, using the 
      # vimeo_client_id and vimeo_access_token defined in site/config.yml and
      # vimeo_client_secret and vimeo_access_token_secret defined in environment
      # variables
      # 
      # Returns an OAuth::AccessToken for the Vimeo API 
      def access_token
        if @access_token
          @access_token
        else
          if not ENV['vimeo_client_secret']
            puts 'Cannot fetch video info from vimeo, vimeo_client_secret is missing from environment variables'
            return
          end
          if not site.vimeo_client_id
            puts 'Cannot fetch video info vimeo, vimeo_client_id is missing from _config/site.yml'
            return
          end
          if not ENV['vimeo_access_token_secret']
            puts 'Cannot fetch video info from vimeo, vimeo_access_token_secret is missing from environment variables'
            return
          end
          if not site.vimeo_access_token
            puts 'Cannot fetch video info from vimeo, vimeo_access_token is missing from _config/site.yml'
            return
          end
          consumer = OAuth::Consumer.new(site.vimeo_client_id, ENV['vimeo_client_secret'],
            { :site => "https://vimeo.com",
              :scheme => :header
            })
          # now create the access token object from passed values
          token_hash = { :oauth_token => site.vimeo_access_token,
                         :oauth_token_secret => ENV['vimeo_access_token_secret']
                       }
          OAuth::AccessToken.from_hash(consumer, token_hash )
        end
      end
    end
  end
end
