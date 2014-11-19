require 'aweplug/cache'

module Aweplug
  module Helpers
    module Video
      class VideoBase

        def initialize(video, site, default_ttl = 86400) # A day seems good for videos
          cache = Aweplug::Cache.default site, default_ttl
          @site = site
          @video = video
          @searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url, 
                                                          :authenticate => true, 
                                                          :searchisko_username => ENV['dcp_user'], 
                                                          :searchisko_password => ENV['dcp_password'], 
                                                          :cache => cache,
                                                          :logger => @site.log_faraday,
                                                          :searchisko_warnings => @site.searchisko_warnings})
        end

        # Create the basic methods
        [:title, :tags].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || ''
          end
        end

        # Create the unimplemented methods
        [:cast, :duration, :modified_date, :published_date, :normalized_cast].each do |attr|
          define_method attr.to_s do
            nil
          end
        end

        # Create the height and width methods
        [:height, :width].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || nil
          end
        end
        
        def description
          d = @video["description"]
          out = ""
          if d
            i = 0
            max_length = 150
            d.scan(/[^\.!?]+[\.!?]\s/).map(&:strip).each do |s|
              i += s.length
              if i > max_length
                out = s[0..max_length]
                break
              else
                out += s
              end
            end
            # Deal with the case that the description has no sentence end in it
            out = (out.empty? || out.length < 60) ? d : out
          end
          out = out.gsub("\n", ' ')[0..150]
          out
        end

        def detail_url
          "#{@site.base_url}/video/#{provider}/#{id}"
        end

        def normalized_author
          normalized_cast[0]
        end

        def author
          cast[0]
        end

        def searchisko_payload
          {
            :sys_title => title,
            :sys_description => description,
            :sys_url_view => detail_url,
            :author => author.nil? ? nil : author['username'],
            :contributors => cast.empty? ? nil : cast.collect {|c| c['username']},
            :sys_created => published_date.iso8601,
            :sys_last_activity_date => modified_date.iso8601,
            :duration => duration.to_i,
            :thumbnail => thumb_url,
            :tags => tags
          }.reject{ |k,v| v.nil? }
        end

        def contributor_exclude
          contributor_exclude = Pathname.new(@site.dir).join("_config").join("searchisko_contributor_exclude.yml")
          if contributor_exclude.exist?
            yaml = YAML.load_file(contributor_exclude)
            return yaml[provider] unless yaml[provider].nil?
          end
          {}
        end

      end
    end
  end
end

