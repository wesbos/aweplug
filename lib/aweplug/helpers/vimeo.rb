require 'oauth'
require 'aweplug/cache/yaml_file_cache'

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
        video = get_video(url)
        #out = %Q[<div class="embedded-media">] +
        %Q[<h4>#{video.title}</h4><div class="flex-video widescreen vimeo">] +
          %Q[<iframe src="//player.vimeo.com/video/#{video.id}\?title=0&byline=0&portrait=0&badge=0&color=2664A2" width="500" height="313" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen}></iframe>] +
        %Q[</div>]
        #video.cast.each do |c|
          #out += %Q[<div class="follow-links">] +
            #%Q[<span class="title">Follow #{first_name(c.display_name)}</span>] +
            ## TODO add in follow links
            #%Q[<a><i class="icon-rss"></i></a>] +
            #%Q[<a><i class="icon-facebook"></i></a>] +
            #%Q[<a><i class="icon-twitter"></i></a>] +
            #%Q[<a><i class="icon-linkedin"></i></a>] +
            #%Q[</div>]
        #end
      end

      # Public: Embeds a vimeo video thumbnail into a web page. Retrieves the title
      # and video cast from vimeo using the authenticated API.
      #
      # url - the URL of the vimeo page for the video to display
      #
      # Returns the html snippet.
      def vimeo_thumb(url)
        video = get_video(url)
        out = %Q{<a href="#{video.detail_url}">} +
        %Q{<img src="#{video.thumb_url}" />} +
          %Q{</a>} +
          %Q{<span class="label material-duration">#{video.duration}</span>} +
          # TODO Add this in once the DCP supports manually adding tags
          # %Q{<span class="label material-level-beginner">Beginner<span>} +
          %Q{<h4><a href="#{video.detail_url}">#{video.title}</a></h4>} +
          # TODO Wire in link to profile URL
          %Q{<p class="author">Author: #{video.author.display_name}</p>} +
          %Q{<p class="material-datestamp">Added #{video.upload_date}</p>} +
          # TODO wire in ratings
          #%Q{<p class="rating">Video<i class="fa fa-star"></i><i class="fa fa-star"></i><i class="fa fa-star"></i><i class="fa fa-star-half-empty"></i><i class="fa fa-star-empty"></i></p>} +
          %Q{<div class="body"><p>#{video.description}</p></div>}
        out
      end

      # Internal: Retrieves the video object
      #
      # url: the Vimeo URL to retrieve the video from
      def get_video(url)
        if site.video_cache.nil?
          site.send('video_cache=', {})
        end
        if site.video_cache.key?(url)
          site.video_cache[url]
        else
          video = Video.new(url, access_token, site)
          site.video_cache[url] = video
          video
        end
      end



      # Internal: Extracts a firstname from a full name
      #
      # full_name - the full name, e.g. Pete Muir
      def first_name(full_name)
        (full_name.nil?) ? full_name : full_name.split[0]
      end

      # Internal: Data object to hold and parse values from the Vimeo API.
      class Video 
        include Aweplug::Helpers::Vimeo

        def initialize(url, access_token, site)
          @id = url.match(/^.*\/(\d*)$/)[1]
          @site = site
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end
          @cache = site.cache
          @access_token = access_token
          fetch_info
          fetch_cast
          fetch_thumb_url
          #log
        end

        def log
          File.open("_tmp/vimeo_fetch.log", 'a') { |f| f.write(
          "------------------------------------\n" +
          "Id: #{@id}\n" + 
          "Cast: #{@cast}\n" + 
          "Author: #{author}\n") }
        end

        def id
          @id
        end

        def title
          @video["title"]
        end

        def duration
          t = Integer @video["duration"]
          Time.at(t).utc.strftime("%T")
        end

        def modified_date
          pretty_date(@video["modified_date"])
        end

        def upload_date
          pretty_date(@video["upload_date"])
        end

        def detail_url
          "#{@site.base_url}/video/vimeo/#{id}"
        end

        def description
          d = @video["description"]
          out = ""
          if d
            i = 0
            max_length = 150
            d.scan(/[^\.!?]+[\.!?]/).map(&:strip).each do |s|
              i += s.length
              if i > max_length
                break
              else
                out += s
              end
            end
            # Deal with the case that the description has no sentence end in it
            out = out.empty? ? d : out
          end
          out
        end

        def author
          @cast[0] ? @cast[0] : OpenStruct.new({"display_name" => "Unknown"})
        end

        def cast
          @cast
        end

        def tags
          r = []
          if @video['tags'].is_a? Hash
            @video['tags']['tag'].inject([]) do |result, element|
              r << element['normalized']
            end
          end
          r
        end

        def thumb_url
          @thumb["_content"] || ''
        end

        def fetch_info 
          if @cache.read(@id).nil?  
            body = exec_method "vimeo.videos.getInfo", @id
            json = JSON.parse(body)
            if json["stat"] == "fail"
              puts "Error fetching info for video: #{@id}. Vimeo says \"#{json["err"]["msg"]}\" and explains \"#{json["err"]["expl"]}\"."
              @fetch_failed = true
              @video = {"title" => json["err"]["msg"]}
            else
              begin
                @video = json["video"][0]
                @cache.write(@id, body)
              rescue Exception => e
                puts "Error parsing response for video #{@id}"
                puts "Response from server: "
                puts body 
              end
            end
          else
            @video = JSON.parse(@cache.read(@id))['video'][0]
          end
        end

        def searchisko_payload
          unless @fetch_failed
            cast_as_hash = []
            @cast.each do |c|
              cast_as_hash << c.marshal_dump
            end
            author_as_hash = @cast[0] ? @cast[0].marshal_dump : {}
            searchisko_payload = {
              :sys_title => title,
              :sys_description => description,
              :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
              :sys_type => 'jbossdeveloper_video',
              :author => author_as_hash,
              :contributors => cast_as_hash,
              :sys_created => DateTime.parse(@video["upload_date"]).iso8601,
              :sys_last_activity_date => DateTime.parse(@video["modified_date"]).iso8601,
              :duration => duration_in_seconds,
              :thumbnail => thumb_url,
              :tags => tags
            }
          end
        end

        def duration_in_seconds
          a = @video["duration"].split(":").reverse
          (a.length > 0 ? a[0].to_i : 0) + (a.length > 1 ? a[1].to_i * 60 : 0) + (a.length > 2 ? a[2].to_i * 60 : 0)
        end

        def fetch_thumb_url
          if @video['thumbnails']
            @thumb = @video["thumbnails"]["thumbnail"][1]
          else
            @thumb = {"_content" => ""}
          end
        end

        def fetch_cast
          @cast = []
          if @video['cast']
            cast = @video['cast']
            if cast['member'].is_a? Hash
              if cast['member']['username'] != 'jbossdeveloper'
                @cast << OpenStruct.new(cast['member'])
              end 
            else
              cast["member"].each do |c|
                o = OpenStruct.new(c)
                if o.username != "jbossdeveloper"
                  @cast << o
                end
              end
            end
          end 
        end

        # Internal: Execute a method against the Vimeo API
        #
        # method   - the API method to execute
        # video_id - the id of the video to execute the method for
        #
        # Returns JSON retreived from the Vimeo API
        def exec_method(method, video_id)
          if access_token
            query = "http://vimeo.com/api/rest/v2?method=#{method}&video_id=#{video_id}&format=json"
            access_token.get(query).body
          end
        end

        def pretty_date(date_str)
          date = DateTime.parse(date_str)
          a = (Time.now-date.to_time).to_i

          case a
            when 0 then 'just now'
            when 1 then 'a second ago'
            when 2..59 then a.to_s+' seconds ago' 
            when 60..119 then 'a minute ago' #120 = 2 minutes
            when 120..3540 then (a/60).to_i.to_s+' minutes ago'
            when 3541..7100 then 'an hour ago' # 3600 = 1 hour
            when 7101..82800 then ((a+99)/3600).to_i.to_s+' hours ago' 
            when 82801..172000 then 'a day ago' # 86400 = 1 day
            when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+' days ago'
            when 518400..1036800 then 'a week ago'
            when 1036800..4147200 then ((a+180000)/(60*60*24*7)).to_i.to_s+' weeks ago'
            else date.strftime("%F")
          end
        end

      end

      # Internal: Obtains an OAuth::AcccessToken for the Vimeo API, using the 
      # vimeo_client_id and vimeo_access_token defined in site/config.yml and
      # vimeo_client_secret and vimeo_access_token_secret defined in environment
      # variables
      #
      # site - Awestruct Site instance
      # 
      # Returns an OAuth::AccessToken for the Vimeo API 
      def access_token
        site ||= @site
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
