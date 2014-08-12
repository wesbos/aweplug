module Aweplug
  module Helpers
    class Video 

      def initialize(video, site)
        @site = site
        if site.cache.nil?
          site.send('cache=', Aweplug::Cache::YamlFileCache.new)
        end
        @cache = site.cache
        @video = video
      end

      # Create the basic methods
      [:detail_url, :height, :id, :thumb_url, :title, :width].each do |attr|
        define_method attr.to_s do
          @video[attr.to_s] || ''
        end
      end

      # Create date methods
      [:modified_date, :upload_date, :update_date].each do |attr|
        define_method attr.to_s do
          pretty_date(@video[attr.to_s])
        end

        define_method "#{attr.to_s}_iso8601" do
          DateTime.parse(@video[attr.to_s]).iso8601
        end
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
        raise NotImplementedError
      end

      def cast
        raise NotImplementedError
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

      def searchisko_payload
        raise NotImplementedError
      end

      def contributor_exclude
        contributor_exclude = Pathname.new(@site.dir).join("_config").join("searchisko_contributor_exclude.yml")
        if contributor_exclude.exist?
          yaml = YAML.load_file(contributor_exclude)
          return yaml['vimeo'] unless yaml['vimeo'].nil?
        end
        {}
      end

      def duration
        raise NotImplementedError
      end

      def duration_in_seconds
        raise NotImplementedError
      end

      def duration_iso8601
        raise NotImplementedError
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
  end
end

