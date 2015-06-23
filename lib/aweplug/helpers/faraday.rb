require 'logger'
require 'faraday'
require 'faraday_middleware'
require 'aweplug/middleware/statuslogger'

module Aweplug
  module Helpers
    # Helper for faraday actions
    class FaradayHelper
      # Public: Returns a basic Faraday connection using options passed in
      #
      # url:  Required url (String or URI) for the base of the full URL.
      # opts: Hash of options to use.
      #       :logger - Logger to use, if none is provided a default is used.
      #       :cache - Optional cache to use.
      #       :no_cache - Boolean indicating not to use a cache.
      #       :adapter - Faraday Adapter to use, :net_http by default.
      #
      # Returns a configured Faraday connection.
      def self.default url, opts = {} 
        logger = opts[:logger] || Logger.new('_tmp/faraday.log', 'daily')

        conn = Faraday.new(url: url) do |builder|
          builder.response :logger, logger
          unless opts[:no_cache]
            builder.use FaradayMiddleware::Caching, (opts[:cache] || Aweplug::Cache::FileCache.new), {} 
          end
          builder.adapter (opts[:adapter] ||:net_http)
          builder.options.params_encoder = Faraday::FlatParamsEncoder
          builder.use Aweplug::Middleware::StatusLogger
          builder.use FaradayMiddleware::FollowRedirects
          builder.ssl.verify = true
        end 
        conn
      end
    end
  end
end
