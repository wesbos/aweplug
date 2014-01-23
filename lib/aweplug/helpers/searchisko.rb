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
    #
    # Returns a new instance of Searchisko.
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

    # Public: Performs a GET search against the Searchisko instance using 
    # provided parameters.
    #
    # params - Hash of parameters to use as query string. See
    #          http://docs.jbossorg.apiary.io/#searchapi for more information
    #          about parameters and how they affect the search.
    #
    # Example
    #
    #   searchisko.search {:query => 'Search query'}
    #   # => {...}
    #
    # Returns the String result of the search.
    def search params = {}
      get '/search', params
    end

    # Public: Makes an HTTP GET to host/v1/rest/#{path} and returns the 
    # result from the Faraday request.
    #
    # path   - String containing the rest of the path.
    # params - Hash containing query string parameters.
    #
    # Example
    #   
    #   searchisko.get 'feed', {:query => 'Search Query'}
    #   # => Faraday Response Object
    #
    # Returns the Faraday Response for the request.
    def get path, params = {}
      @faraday.get "/v1/rest/" + path, params
    end

    # Public: Posts content to Searchisko.
    #
    # content_type - String of the Searchisko sys_content_type for the content 
    #                being posted.
    # content_id   - String of the Searchisko sys_content_id for the content.
    # params       - Hash containing the content to push.
    #
    # Examples
    #
    #   searchisko.push_content 'jbossdeveloper_bom', id, content_hash
    #   # => Faraday Response
    #
    # Returns a Faraday Response from the POST.
    def push_content content_type, content_id, params = {}
      post "/content/#{content_type}/#{content_id}", params
    end

    # Public: Perform an HTTP POST to Searchisko.
    #
    # path   - String containing the rest of the path.
    # params - Hash containing the POST body.
    #
    # Examples
    #
    #   searchisko.post "rating/#{searchisko_document_id}", {rating: 3}
    #   # => Faraday Response
    def post path, params = {}
      @faraday.post do |req|
        req.url "/v1/rest/" + path
        req.headers['Content-Type'] = 'application/json'
        req.body = params
      end
    end
  end
end
