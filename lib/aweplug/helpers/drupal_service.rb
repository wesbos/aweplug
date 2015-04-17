require 'logger'
require 'aweplug/helpers/faraday'
require 'logger'
require 'json'
require 'uri'

module Aweplug
  module Helpers
    # Public: A helper class for using drupal services.
    class DrupalService 

      def self.default site
        Aweplug::Helpers::DrupalService.new({:base_url => site.drupal_base_url, 
                                          :drupal_user => ENV['drupal_user'], 
                                          :drupal_password => ENV['drupal_password']})
      end

      # Public: Initialization of the object, keeps a Faraday connection cached.
      #
      # opts - symbol keyed hash, see Aweplug::Helpers::Faraday.default for 
      #        other options. Current keys used:
      #        :base_url - base url for the searchisko instance
      #        :drupal_username - Username to use for auth
      #        :drupal_password - Password to use for auth
      #
      # Returns a new instance of Searchisko.
      def initialize opts={} 
        unless [:drupal_user, :drupal_password].all? {|required| opts.key? required}
          raise 'Missing drupal credentials'
        end
        @logger = Logger.new('_tmp/drupal.log', 'daily')
        opts.merge({:no_cache => true, :logger => @logger})
        @faraday = Aweplug::Helpers::FaradayHelper.default(opts[:base_url], opts)
        session_info = JSON.parse (login opts[:drupal_user], opts[:drupal_password]).body
        @cookie = "#{session_info['session_name']}=#{session_info['sessid']}"
        @token = token opts[:drupal_user], opts[:drupal_password]
      end

      def send_page page, content
        path = page.output_path.chomp('index.html').gsub('/', '')
        payload = {:title => (page.title || page.site.title || path),
                   :type => "awestruct_page",
                   :body => {:und => [{:value => content, 
                                       :summary => page.description,
                                       :format => "full_html"}]},
                   :field_output_path => {:und => [{:value => page.output_path.chomp('index.html')}]}
                  }

        # TODO: cache this so we know to update or create
        post 'content', 'node', payload
      end

      # Public: Makes an HTTP GET to host/endpoint/#{path} and returns the 
      # result from the Faraday request.
      #
      # endpoint  - String containing endpoint to the service.
      # path      - String containing the rest of the path.
      # params    - Hash containing query string parameters.
      #
      # Example
      #   
      #   drupal.get 'api', 'node/7'
      #   # => Faraday Response Object
      #
      # Returns the Faraday Response for the request.
      def get endpoint, path, params = {}
        response = @faraday.get URI.escape(endpoint + "/" + path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['Accept'] = 'application/json'
          req.headers['X-CSRF-Token'] = @token
          req.headers['Cookie'] = @cookie if @cookie
          req.params = params
        end
        unless response.success?
          $LOG.warn "Error making drupal request to #{path}. Status: #{response.status}. Params: #{params}" if $LOG.warn?
        end
        response
      end

      # Public: Perform an HTTP POST to drupal.
      #
      # endpoint  - String containing endpoint to the service.
      # path      - String containing the rest of the path.
      # params    - Hash containing query string parameters.
      #
      # Examples
      #
      #   drupal.post "api", "node", {title: 'Hello', type: 'page'}
      #   # => Faraday Response
      def post endpoint, path, params = {}
        resp = @faraday.post do |req|
          req.url endpoint + "/" + path
          req.headers['Content-Type'] = 'application/json'
          req.headers['Accept'] = 'application/json'
          req.headers['X-CSRF-Token'] = @token if @token
          req.headers['Cookie'] = @cookie if @cookie
          unless params.is_a? String
            req.body = params.to_json
          else
            req.body = params
          end
          if @logger
            @logger.debug "request body: #{req.body}"
          end
        end
        if !resp.success?
          @logger.debug "response body: #{resp.body}"
          if $LOG.error
            $LOG.error "Error making drupal request to '#{path}'. Status: #{resp.status}. 
Params: #{params}. Response body: #{resp.body}"
          end
        end
        resp
      end

      # Public: Perform an HTTP PUT to drupal.
      #
      # endpoint  - String containing endpoint to the service.
      # path      - String containing the rest of the path.
      # params    - Hash containing query string parameters.
      #
      # Examples
      #
      #   drupal.put "api", "node/7", {title: 'Better Title', log: 'Update Title'}
      #   # => Faraday Response
      def put endpoint, path, params = {}
        resp = @faraday.put do |req|
          req.url endpoint + "/" + path
          req.headers['Content-Type'] = 'application/json'
          req.headers['Accept'] = 'application/json'
          req.headers['X-CSRF-Token'] = @token
          req.headers['Cookie'] = @cookie if @cookie
          unless params.is_a? String
            req.body = params.to_json
          else
            req.body = params
          end
          if @logger
            @logger.debug "request body: #{req.body}"
          end
        end
        if !resp.success?
          @logger.debug "response body: #{resp.body}"
          if $LOG.error
            $LOG.error "Error making drupal request to '#{path}'. Status: #{resp.status}. 
Params: #{params}. Response body: #{resp.body}"
          end
        end
        resp
      end

      private

      def login username, password
        post 'content', 'user/login', {:username => username, :password => password}
      end

      def token username, password
        JSON.parse((post 'content', 'user/token', {:username => username, :password => password}).body)['token']
      end
    end
  end
end

