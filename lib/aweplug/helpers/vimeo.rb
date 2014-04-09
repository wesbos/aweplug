require 'oauth'
require 'aweplug/cache/yaml_file_cache'
require 'aweplug/helpers/identity'
require 'tilt'

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

      protected 

      def render(video, default_snippet, snippet)
        if !video.fetch_failed
          if snippet
            path = Pathname.new(site.dir).join("_partials").join(snippet)
          else
            path = Pathname.new(File.dirname(__FILE__)).join(default_snippet)
          end
          Tilt.new(path.to_s).render(Object.new, :video => video)
        end
      end

      # Internal: Retrieves the video object
      #
      # url: the Vimeo URL to retrieve the video from
      



      # Internal: Extracts a firstname from a full name
      #
      # full_name - the full name, e.g. Pete Muir
      def first_name(full_name)
        (full_name.nil?) ? full_name : full_name.split[0]
      end

      # Internal: Data object to hold and parse values from the Vimeo API.
      class Video 
        include Aweplug::Helpers::Vimeo

        attr_reader :fetch_failed

        def initialize(url, access_token, site)
          @id = url.match(/^.*\/(\d*)$/)[1]
          @site = site
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end
          @cache = site.cache
          @access_token = access_token
          fetch_info
          load_thumb_url
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

        def upload_date_iso8601
          DateTime.parse(@video["upload_date"]).iso8601
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
          cast[0] ? cast[0] : OpenStruct.new({"display_name" => "Unknown"})
        end

        def cast
          unless @cast
            load_cast
          end
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
              @fetch_failed = false
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
          cast = []
          unless @fetch_failed
            if @video['cast']['member'].is_a? Array
              @video['cast']['member'].each do |m|
                if m['username'] != 'jbossdeveloper'
                  cast << m['username']
                end
              end
            elsif @video['cast']['member'] && @video['cast']['member']['username'] != 'jbossdeveloper'
              cast << @video['cast']['member']
            end
            author = cast.length > 0 ? cast[0] : nil
            searchisko_payload = {
              :sys_title => title,
              :sys_description => description,
              :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
              :author => author,
              :contributors => cast.empty? ? nil : cast,
              :sys_created => upload_date_iso8601,
              :sys_last_activity_date => DateTime.parse(@video["modified_date"]).iso8601,
              :duration => duration_in_seconds,
              :thumbnail => thumb_url,
              :tags => tags
            }.reject{ |k,v| v.nil? }
          end
        end

        def duration_in_seconds
          a = @video["duration"].split(":").reverse
          (a.length > 0 ? a[0].to_i : 0) + (a.length > 1 ? a[1].to_i * 60 : 0) + (a.length > 2 ? a[2].to_i * 60 : 0)
        end

        def load_thumb_url
          if @video['thumbnails']
            @thumb = @video["thumbnails"]["thumbnail"][1]
          else
            @thumb = {"_content" => ""}
          end
        end

        def load_cast
          @cast = []
          if @site.identity_manager && @video['cast']
            cast = @video['cast']
            if cast['member'].is_a?(Hash) && cast['member']['username'] != 'jbossdeveloper'
              prototype = Aweplug::Identity::Contributor.new({"accounts" => {"vimeo.com" => {"username" => cast['member']['username']}}})
              contrib = @site.identity_manager.get(prototype)
              @cast << contrib
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
