require 'aweplug/helpers/video/video_base'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/searchisko'
require 'duration'
require 'ostruct'

module Aweplug
  module Helpers
    module Video
      # Internal: Data object to hold and parse values from the Vimeo API.
      class VimeoVideo < ::Aweplug::Helpers::Video::VideoBase
        include Aweplug::Helpers::SearchiskoSocial

        attr_reader :duration, :id, :tags, :url, :title, :thumb_url, :cast, :modified_date, :published_date, :normalized_cast

        def initialize video, credits, site
          super video, site
          @duration = Duration.new(@video['duration'])
          @id = @video['uri'].slice(8, @video['uri'].length)
          @tags = @video['tags'].collect { |t| t['canonical'] }
          @url = @video['link']
          @title = @video['name']
          @thumb_url = @video['pictures'].find {|p| p['width'] == 200}['link']
          @modified_date = DateTime.parse(@video['modified_time'])
          @published_date = DateTime.parse(@video['created_time'])
          @cast = []
          credits.each do |c|
            name = c['name']
            if c.has_key? 'user'
              username = c['user']['link'].slice(18, c['user']['link'].length)
            else
              username = name
            end
            unless contributor_exclude.include? username
              @cast << { :username => username, :name => name }
            end
          end
          @normalized_cast = @cast.collect { |c| normalize('contributor_profile_by_vimeo_username', c[:username], @searchisko, c[:name]) }
        end

        def provider
          'vimeo'
        end

        def contributor_exclude
          super + ['jbossdeveloper']
        end

        def embed color, width, height
          %Q{<div widescreen vimeo><iframe src="//player.vimeo.com/video/#{id}?title=0&byline=0&portrait=0&badge=0&color=#{color}" width="#{width}" height="#{height}" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe></div>}
        end

      end
    end
  end
end

