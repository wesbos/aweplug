require 'oauth'
require 'aweplug/cache/file_cache'
require 'aweplug/cache/jdg_cache'
require 'aweplug/helpers/video/vimeo_video'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/video/helpers'
require 'tilt'
require 'yaml'
require 'faraday'
require 'faraday_middleware'

module Aweplug
  module Helpers
    module Video
      class Vimeo
        include Aweplug::Helpers::Video::Helpers

        VIMEO_URL_PATTERN = /^https?:\/\/vimeo\.com\/(album)?\/?([0-9]+)\/?$/
        BASE_URL = 'https://api.vimeo.com/'

        def initialize site, logger: true, raise_error: false, adapter: nil
          @site = site

          if (site.cache.nil?)
            if (site.profile =~ /development/)
              cache = Aweplug::Cache::FileCache.new 
            else
              cache = Aweplug::Cache::JDGCache.new(ENV['cache_url'], ENV['cache_user'], ENV['cache_password'])
            end

            site.send('cache=', cache)
          end
          @faraday = Faraday.new(:url => BASE_URL) do |builder|
            if (logger) 
              if (logger.is_a?(::Logger))
                builder.response :logger, @logger = logger
              else 
                builder.response :logger, @logger = ::Logger.new('_tmp/faraday.log', 'daily')
              end
            end
            builder.request :url_encoded
            builder.request :retry
            builder.response :gzip
            builder.request :authorization, 'bearer', ENV['vimeo_access_token']
            builder.use FaradayMiddleware::FollowRedirects
            builder.use FaradayMiddleware::Caching, site.cache, {}
            builder.adapter adapter || :net_http
          end
        end

        def add(url, product: nil, push_to_searchisko: true)
          if url =~ VIMEO_URL_PATTERN
            if $1 == 'album'
              path = "me/albums/#{$2}/videos"
              while !path.nil?
                resp = @faraday.get(path, {per_page: 50})
                path = nil
                if resp.success?
                  json = JSON.load(resp.body)
                  json['data'].collect do |v|
                    if v['metadata']['connections'].has_key? 'credits'
                      respc = @faraday.get(v['metadata']['connections']['credits'])
                      if respc.success?
                        data = JSON.load(respc.body)['data']
                        _add(data[0]['video'], data, product, push_to_searchisko)
                      else
                        puts "Error loading #{v['metadata']['connections']['credits']}"
                      end
                    else
                      _add(v['data'][0], nil, product, push_to_searchisko)
                    end
                  end
                  path = json['paging']['next']
                else
                  puts "Error loading #{path}"
                end
              end
            else
              uri = "videos/#{$2}/credits"
              resp = @faraday.get(uri)
              if resp.success?
                data = JSON.load(resp.body)['data']
                _add(data[0]['video'], data, product, push_to_searchisko)
              else
                puts "Error loading #{uri}"
              end
            end
          end
        end

        private
        
        def _add video, data, product, push_to_searchisko
          add_video(Aweplug::Helpers::Video::VimeoVideo.new(video, data, @site), product, push_to_searchisko)
        end

      end
    end
  end
end

