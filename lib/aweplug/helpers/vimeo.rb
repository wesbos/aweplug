require 'oauth'
require 'aweplug/cache/yaml_file_cache'
require 'aweplug/helpers/video'
require 'aweplug/helpers/searchisko_social'
require 'tilt'
require 'yaml'

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
          id = url.split('http://vimeo.com/').last
          videoJson = exec_method "vimeo.videos.getInfo", 
                                  {format: 'json', video_id: id}
          video = VimeoVideo.new(JSON.load(videoJson)['video'].first, site)
          site.video_cache[url] = video
          video
        end
      end

      protected 

      def render(video, default_snippet, snippet)
        if !video.fetch_failed
          if snippet
            path = snippet
          else
            path = default_snippet
          end
          if !File.exists?("#{site.dir}/_partials/#{path}")
            path = Pathname.new(File.dirname(__FILE__)).join(default_snippet)
            Tilt.new(path.to_s).render(Object.new, :video => video, :page => page, :site => site)
          else
            partial path, {:video => video, :parent => page}
          end
        end
      end

      # Internal: Extracts a firstname from a full name
      #
      # full_name - the full name, e.g. Pete Muir
      def first_name(full_name)
        (full_name.nil?) ? full_name : full_name.split[0]
      end 

      # Internal: Execute a method against the Vimeo API
      #
      # method   - the API method to execute
      # options  - Hash of the options (names and values) to send to Vimeo
      #
      # Returns JSON retreived from the Vimeo API
      def exec_method(method, options)
        if access_token
          query = "http://vimeo.com/api/rest/v2?method=#{method}&" 
          query += options.inject([]) {|a, (k,v)| a << "#{k}=#{v}"; a}.join("&")
          access_token.get(query).body
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

      # Internal: Data object to hold and parse values from the Vimeo API.
      class VimeoVideo < ::Aweplug::Helpers::Video
        include Aweplug::Helpers::Vimeo
        include Aweplug::Helpers::SearchiskoSocial

        attr_reader :fetch_failed

        def url
          @video['urls']['url'].first['_content']
        end

        def thumb_url
          @video['thumbnails']['thumbnail'][1]['_content']
        end

        def duration
          t = Integer @video["duration"]
          Time.at(t).utc.strftime("%T")
        end

        def duration_in_seconds
          a = @video["duration"].split(":").reverse
          (a.length > 0 ? a[0].to_i : 0) + (a.length > 1 ? a[1].to_i * 60 : 0) + (a.length > 2 ? a[2].to_i * 60 : 0)
        end

        def duration_iso8601
          t = Integer @video["duration"]
          Time.at(t).utc.strftime("PT%HH%MM%SS")
        end

        def detail_url
          "#{@site.base_url}/video/vimeo/#{id}"
        end

        def author
          cast[0]
        end

        def cast
          unless @cast
            load_cast
          end
          @cast
        end

        def load_cast
          @cast = []
          unless @video['cast'].nil? || @video['cast']['member'].nil?
            members = [@video['cast']['member']].flatten
            searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url, 
                                              :authenticate => true, 
                                              :searchisko_username => ENV['dcp_user'], 
                                              :searchisko_password => ENV['dcp_password'], 
                                              :cache => @site.cache,
                                              :logger => @site.log_faraday,
                                              :searchisko_warnings => @site.searchisko_warnings})
            members.each do |member|
              unless member['username'] == 'jbossdeveloper'
                searchisko.normalize('contributor_profile_by_vimeo_username', member['username']) do |contributor|
                  if !contributor['sys_contributor'].nil?
                    @cast << add_social_links(contributor['contributor_profile'])
                  elsif !member['display_name'].nil? && !member['display_name'].strip.empty?
                    @cast << OpenStruct.new({:sys_title => member['display_name']})
                  end
                end
            end
            end 
          end 
        end

        def searchisko_payload
          cast = []
          unless @fetch_failed
            excludes = contributor_exclude
            if @video['cast']['member'].is_a? Array
              @video['cast']['member'].each do |m|
                if m['username'] != 'jbossdeveloper'
                  cast << m['username'] unless excludes.include? m['username']
                end
              end
            elsif @video['cast']['member'] && @video['cast']['member']['username'] != 'jbossdeveloper'
              cast << @video['cast']['member']['username'] unless excludes.include? @video['cast']['member']['username']
            end
            author = cast.length > 0 ? cast[0] : nil
            {
              :sys_title => title,
              :sys_description => description,
              :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
              :author => author,
              :contributors => cast.empty? ? nil : cast,
              :sys_created => upload_date_iso8601,
              :sys_last_activity_date => modified_date_iso8601,
              :duration => duration_in_seconds,
              :thumbnail => thumb_url,
              :tags => tags
            }.reject{ |k,v| v.nil? }
          end
        end
      end

    end
  end
end
