require 'aweplug/cache/file_cache'
require 'aweplug/cache/jdg_cache'

module Aweplug
  module Cache
    # Public, returns a default cache based on the profile being run.
    #
    # site        - Awestruct Site
    # default_ttl - Time in seconds for the default ttl for the cache
    #
    # Returns the cache for the profile.
    def self.default site, default_ttl = 360 
      if (site.profile =~ /development/)
        cache = Aweplug::Cache::FileCache.new 
      else
        cache = Aweplug::Cache::JDGCache.new(site.profile, ENV['cache_url'], ENV['cache_user'], ENV['cache_password'], default_ttl)
      end
    end
  end
end
