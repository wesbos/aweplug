module Aweplug
  module Middleware

    class StatusLogger < Faraday::Middleware
      
      # Public, returns a successful response 
      # app - the nested middleware stack
      # env - a hash of the request/response information 
      #
      # returns an Faraday::Response containing an env hash.
      def initialize(app) 
      @app = app
      end

      def call(env) 
        url = env[:url].to_s
        response = @app.call(env)
        raise("#{url} returned a response of #{response.status}") unless response.success?
        response
      end
    end

  end
end