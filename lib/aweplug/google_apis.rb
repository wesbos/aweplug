require 'google/api_client'
require 'aweplug/cache'
require 'faraday'
require 'faraday_middleware'

module Aweplug
  module GoogleAPIs

    # Helpers for working with Google APIs

    # Get the Google API Client
    def google_client site, logger: true, authenticate: true, readonly: true
      Aweplug::Cache.default site

      opts = { :application_name => site.application_name, :application_version => site.application_version }
      opts.merge!({:key => ENV['google_api_key']}) if authenticate && readonly
      opts.merge!({:authorization => nil})  if readonly
      # TODO Add write access
      client = Google::APIClient.new opts 
      faraday = Faraday.new do |builder|
        if (logger) 
          if (logger.is_a?(::Logger))
            builder.response :logger, @logger = logger
          else 
            builder.response :logger, @logger = ::Logger.new('_tmp/faraday.log', 'daily')
          end
        end
        builder.use FaradayMiddleware::Caching, site.cache, {}
        builder.adapter :net_http
        builder.response :gzip
        builder.options.params_encoder = Faraday::FlatParamsEncoder
        builder.ssl.ca_file = client.connection.ssl.ca_file
        builder.ssl.verify = true
      end
      client.connection = faraday
      client
    end

  end
end
