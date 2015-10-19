require 'aweplug/helpers/faraday'
require 'digest/sha1'
require 'faraday'

module Aweplug
  module Cache
    # Public: A simple caching implementation.
    #         Internally it uses JDG, for it's storage. It also saves
    #         data in a hash for the life of the object. Any keys which are 
    #         Strings are frozen before being used.
    class JDGCache
      # Public: Initialization method.
      #
      # profile     - profile the site is built with to prepend to keys.
      # uri         - String or URI containing the JDG URI (required).
      # username    - Username for the JDG instance (required).
      # password    - Password for the JDG instance (required).
      # default_ttl - Seconds (Integer) for the default ttl for items in 
      #               the cache, defaults to nil.
      #
      # Examples
      #
      #   store = Aweplug::Cache::JDGCache.new('http://jdg.mycompany.com/', 'user', 'secret'
      #   store.write('key', 'data')
      #   # => 'data'
      #   store.read('key')
      #   # => 'data'
      #
      #   store = Aweplug::Cache::JDGCache.new(URI::HTTP.build({:host => 'jdg.mycompany.com'}), 'user', 'secret'
      #   store.write('key', 'data')
      #   # => 'data'
      #   store.read('key')
      #   # => 'data'
      #
      # Returns a new instance of the cache.
      def initialize(profile, uri, username, password, default_ttl = nil)
        @profile = profile
        @memory_store = {}
        @conn = Aweplug::Helpers::FaradayHelper.default(uri, {:no_cache => true})
        @conn.builder.delete(Faraday::Response::RaiseError) #remove response status checking since data not in the cache isn't necessarily an error.
        @conn.basic_auth username, password
        @default_ttl = default_ttl
      end

      # Public: Retrieves the data stored previously under the given key.
      #
      # key - key part of a key value pair
      #
      # Examples
      #
      #   store.read('my_key')
      #   # => 'my_data'
      #
      # Returns the data associated with the key.
      def read(key)
        _key = Digest::SHA1.hexdigest key

        unless @memory_store.has_key? _key
          response = @conn.get "/rest/jbossdeveloper/#{@profile}_#{_key}"
          if response.success?
            @memory_store[_key] = Marshal.load(response.body)
          end
        end
        @memory_store[_key]
      end

      # Public: Adds data to the cache.
      #
      # key   - A key for the cache, strings or symbols should be used
      # value - Data to store in the cache
      #
      # Examples
      #   
      #   store.write(:pi, 3.14)
      #   # => 3.14
      #
      # Returns the data just saved.
      def write(key, value, opts = {})
        _key = Digest::SHA1.hexdigest key
        ttl = opts[:ttl] || @default_ttl
 
        # We don't want to cache errors
        return if value.is_a?(Faraday::Response) && !value.success?

        if (value.is_a?(Faraday::Response) && !value.headers['expires'].nil?)
          resp_ttl = DateTime.parse(value.headers['expires']).to_time.to_i - Time.now.to_i
          ttl = resp_ttl if resp_ttl > 0
        end

        _value = Marshal.dump value

        @memory_store[_key] = value
        $LOG.debug "Writing to JDG cache hashed #{_key} for #{key}"
        @conn.put do |req|
          req.url "/rest/jbossdeveloper/#{@profile}_#{_key}"
          req.headers['Content-Type'] = opts[:content_type] || 'application/ruby+object'
          req.headers['timeToLiveSeconds'] = ttl.to_s # need to see if we're actually a request and full from that
          req.body = _value
        end
      end

      # Public: Retrieves the value from the cache, or the return of the Block.
      #
      # key   - Key in the cache to retrieve.
      # block - The block to be evaluated for a default value.
      #
      # Examples
      #
      #   store.fetch(key) { 'new data' }
      #   # => 'new data'
      #   store.write(key, 23)
      #   store.fetch(key) { 'new data' }
      #   # => 23
      #
      # Returns the value in the cache, or the default supplied from the block.
      def fetch(key) 
        read(key) || yield.tap do |data| 
          write(key, data) 
          data
        end
      end
    end
  end
end

