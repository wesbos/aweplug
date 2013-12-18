require 'faraday'
require 'faraday_middleware' 

module Aweplug::Helpers
  # Public: A helper class for using Searchisko.
  class Searchisko 
    # Public: Initialization of the object, keeps a Faraday connection cached.
    #
    # opts - symbol keyed hash. Current keys used:
    #        :base_url - base url for the searchisko instance
    #        :authenticate - boolean flag for authentication
    #        :searchisko_username - Username to use for auth
    #        :searchisko_password - Password to use for auth
    #        :logging - Boolean to log responses
    #        :raise_error - Boolean flag if 404 and 500 should raise exceptions
    #        :adapter - faraday adapter to use, defaults to :net_http
    def initialize opts={} 
      @faraday = Faraday.new(:url => opts[:base_url]) do |builder|
        if opts[:authenticate]
          if opts[:searchisko_username] && opts[:searchisko_password]
            builder.request :basic_auth, opts[:searchisko_username], opts[:searchisko_password]
          else
            $LOG.warn 'Missing username and / or password for searchisko'
          end
        end
        builder.response :logger if opts[:logging]
        builder.response :raise_error if opts[:raise_error]
        #builder.response :json, :content_type => /\bjson$/
        builder.adapter opts[:adapter] || :net_http
      end
    end

    def search params = {}
      get '/search', params
    end

    def get path, params = {}
      @faraday.get "/v1/rest/" + path, params
    end

    def push_content content_type, content_id, params = {}
      post "/content/#{content_type}/#{content_id}", params
    end

    def post path, params = {}
      @faraday.post do |req|
        req.url "/v1/rest/" + path
        req.headers['Content-Type'] = 'application/json'
        req.body = params
      end
    end
  end
end
