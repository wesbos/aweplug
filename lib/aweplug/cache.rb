require 'aweplug/cache/file_cache'
require 'aweplug/cache/jdg_cache'

module Aweplug
  module Cache
    # Public, returns a default cache based on the profile being run.
    #
    # site - Awestruct Site
    #
    # Returns the cache for the profile.
    def self.default site
      if (site.send('cache').nil? || !site.respond_to?('cache'))
        if (site.profile =~ /development/)
          cache = Aweplug::Cache::FileCache.new 
        else
          cache = Aweplug::Cache::JDGCache.new(site.profile, ENV['cache_url'], ENV['cache_user'], ENV['cache_password'])
        end

        site.send('cache=', cache)
      end
      site.cache
    end
  end
end
