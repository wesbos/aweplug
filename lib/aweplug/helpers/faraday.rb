require 'logger'
require 'aweplug/cache/file_cache'
require 'faraday'
require 'faraday_middleware'

module Aweplug
  module Helpers
    # Helper for faraday actions
    class FaradayHelper
      def self.default url, logger = ::Logger.new('_tmp/faraday.log', 'daily'), cache = Aweplug::Cache::FileCache.new
        conn = Faraday.new(url: url) do |builder|
          builder.response :logger, @logger = logger
          builder.use FaradayMiddleware::Caching, cache, {}
          builder.adapter :net_http
          builder.options.params_encoder = Faraday::FlatParamsEncoder
          builder.ssl.verify = true
        end 
        conn
      end
    end
  end
end
