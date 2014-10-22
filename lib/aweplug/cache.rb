require 'aweplug/cache/file_cache'
require 'aweplug/cache/jdg_cache'
require 'aweplug/cache/daybreak_cache'

module Aweplug
  module Cache
    # Public, returns a default cache based on the profile being run.
    #
    # site        - Awestruct Site
    # default_ttl - Time in seconds for the default ttl for the cache, 
    #               defaults to six hours.
    #
    # Returns the cache for the profile.
    def self.default site, default_ttl = 21600
      if (site.profile =~ /development/)
        @@cache ||= Aweplug::Cache::DaybreakCache.new 
      else
        @@cache ||= Aweplug::Cache::JDGCache.new(site.profile, ENV['cache_url'], ENV['cache_user'], ENV['cache_password'], default_ttl)
      end
      @@cache
    end
  end
end

