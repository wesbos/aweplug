require 'yaml/store'
require 'fileutils'

module Aweplug::Cache
  # Public: A simple caching implementation.
  #         Internally it using a YAML::Store for a file backing. It also saves
  #         data in a hash for the life of the object. Any keys which are 
  #         Strings are frozen before being used.
  class YamlFileCache
    # Public: Initialization method.
    #
    # opts - A Hash of options
    #         filename: Name of the File used for caching. Defaults to 
    #         'tmp/cache.store'.
    #
    # Examples
    #
    #   store = Aweplug::Cache::YamlFileCache.new
    #   store.write('key', 'data')
    #   # => 'data'
    #   store.read('key')
    #   # => 'data'
    #
    # Returns a new instance of the cache.
    def initialize(opts = {})
      opts.merge!({filename: '_tmp/cache.store'})
      FileUtils.mkdir_p(File.dirname opts[:filename])
      @file_store = YAML::Store.new opts[:filename]
      @memory_store = {}
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
      key.freeze if key.is_a? String

      if @memory_store.has_key? key
        @memory_store[key]
      else
        @file_store.transaction do
          @memory_store[key] = @file_store[key]
        end
        @memory_store[key]
      end
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
    def write(key, value)
      key.freeze if key.is_a? String

      @memory_store[key] = value
      @file_store.transaction do
        @file_store[key] = value
      end
    end

    # Public: Retreives the value from the cache, or the return of the Block.
    #
    # key   - Key in the cache to retreive.
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
      key.freeze if key.is_a? String

      read(key) || yield.tap { |data| write(key, data) }
    end
  end
end
