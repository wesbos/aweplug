require 'aweplug/helpers/faraday'
require 'uri'

module Aweplug
  module Cache
    # Public: A simple caching implementation.
    #         Internally it uses JDG, for it's storage. It also saves
    #         data in a hash for the life of the object. Any keys which are 
    #         Strings are frozen before being used.
    class JDGCache
      # Public: Initialization method.
      #
      # uri      - String or URI containing the JDG URI (required).
      # username - Username for the JDG instance (required).
      # password - Password for the JDG instance (required).
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
      def initialize(uri, username, password)
        @memory_store = {}
        @conn = Aweplug::Helpers::FaradayHelper.default(uri, {:no_cache => true})
        @conn.basic_auth username, password
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
        raise "key must be a string" unless key.is_a? String
        _key = key.freeze 

        unless @memory_store.has_key? _key
          response = @conn.get URI.escape("/rest/jbossdeveloper/#{_key}")
          if response.success?
            @memory_store[_key] = Marshal.load(response.body)
          else 
            $LOG.error "#{key} not found in jdg or memory"
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
        raise "key must be a string" unless key.is_a? String
        _key = key.freeze 
        ttl = opts[:ttl] || 86400

        if key.is_a? Faraday::Response
          resp_ttl = DateTime.parse(resp.headers['expires']).to_time.to_i - Time.now.to_i
          ttl = resp_ttl if resp_ttl > 0
        end

        _value = Marshal.dump value

        @memory_store[_key] = _value
        @conn.put do |req|
          req.url "/rest/jbossdeveloper/#{_key}"
          req.headers['Content-Type'] = opts[:content_type] || 'application/ruby+object'
          req.headers['timeToLive'] = ttl.to_s # need to see if we're actually a request and full from that
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
        raise "key must be a string" unless key.is_a? String
        _key = key.freeze 

        read(key) || yield.tap { |data| write(key, data) }
      end
    end
  end
end

