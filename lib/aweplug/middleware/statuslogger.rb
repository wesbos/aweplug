module Aweplug
  module Middleware

    # Public. Middleware that raises an exception on unsuccessfull returns.
    # This potentially stops the build, unless handled further up the chain.
    #
    # returns an Faraday::Response containing an env hash.
    class StatusLogger < Faraday::Middleware
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
