require 'aweplug/helpers/searchisko'
require 'awestruct/astruct'
require 'awestruct/page'
require 'json'


module Aweplug
  module Identity

    # Addition to proc, allowing easy registration of callbacks
    refine Proc do
      def callback(callable, *args)
        r = nil
        self === Class.new do
          method_name = callable.to_sym
          define_method(method_name) { |&block| r = block.call(*args) if !block.nil?}
          def method_missing(method_name, *args, &block); end
        end.new
        r
      end
    end

    # A class that represents a contributor, based on an AStruct.
    # It supports parsing a result returned by searchisko, generating
    # a JSON object that can be sent to searchisko, and generating a
    # searchisko query string from a prototype contributor
    #
    # It will remap from searchisko's camel cased contributor profile
    # to snake case, produce an identity map for any accounts
    # present, and construct a list of email addresses.
    class Contributor < Awestruct::AStruct

      using Aweplug::Identity

      # Some attributes from Searchisko are remaped to saner names
      REMAP_ATTRS = {
        "sys_content_provider" => nil,
        "sys_type" => nil,
        "sys_content_type" => nil,
        "sys_id" => nil,
        "sys_title" => nil, 
        "sys_created" => nil,
        "sys_tags" => nil,
        "sys_updated" => nil,
        "sys_url_view" => nil,
        "sys_description" => nil,
        "sys_contributors" => "email_addrs"
      }

      REV_REMAP_ATTRS = REMAP_ATTRS.clone.delete_if{|k, v| v.nil?}.invert

      # Parse a JSON object from Searchisko, creating a contributor
      def self.parse json
        p = parse_h(json) do |on|
          on.accounts do |accounts|
            accounts.collect {|v| [v['domain'], v]}.to_h
          end
          on.email_addrs do |addrs|
            addrs.collect { |a| a.scan(/<(.*?)>/) }.flatten
          end
        end
        Contributor.new p
      end

      # Generate a JSON object that can be understood by searchisko from
      # this contributor
      def to_searchisko
        Contributor::to_h self do |on|
          on.accounts do |v|
            v.map do |k, v|
              v["domain"] = k if v.is_a? Hash
              v
            end
          end
        end
      end

      # Generate a query string from a prototype contributor
      def to_query
        "query=#{Contributor::query_terms(to_searchisko).join(" AND ")}"
      end

      # Merge another contributor into this one. Fields on the other contributor
      # take precedence. Mainly useful for updating a prototype contributor with
      # a result from searchisko
      def merge other
        raise "Not a hash" if !other.is_a? Hash
        Contributor::merge self, other
      end

      private 

      # Recursively extracts query terms as a flat array from a contributor
      def self.query_terms hash, pre = ""
        hash.collect_concat do |k, v|
          if v.is_a? Array
            query_terms( v.map { |n| [k, n] }.to_h, pre )
          elsif v.is_a? Hash
            query_terms v, "#{k}."
          else
            %Q{#{pre}#{k}:"#{v}"}
          end
        end
      end

      # Recursive merge two contributors
      def self.merge orig, other
        res = {}
        orig.each do |k, v|
          if !v.is_a? Hash
            res[k] = v
          elsif !other.has_key? k
            res[k] = merge(v, {})
          end
        end
        
        other.each do |k, v|
          if !v.is_a? Hash
            res[k] = v
          elsif orig.has_key?(k) && orig[k].is_a?(Hash)
            res[k] = merge(orig[k], v)
          else
            res[k] = merge({}, v)
          end
        end
        res
      end

      # Recursively converts the JSON from searchisko to a contributor
      def self.parse_h hash, &block
        hash.map do |(k, v)|
          if REMAP_ATTRS.has_key? k
            if REMAP_ATTRS[k]
              k = REMAP_ATTRS[k]
            else
              # Case that the mapping is nil
              next
            end
          end
          v = block.callback(k, v) || v
          if v.is_a? Hash
            [underscore(k), parse_h(v, &block)]
          else
            [underscore(k), v]
          end
        end
      end

      # Revursively creates a hash that can be converted to a JSON 
      # object that can be sent to searchisko
      def self.to_h hash, &block
        hash.map do |(k, v)|
          if REV_REMAP_ATTRS.has_key? k
            if REV_REMAP_ATTRS[k]
              k = REV_REMAP_ATTRS[k]
            else
              next
            end
          end
          v = block.callback(k, v) || v
          if v.is_a? Hash
            [camel_case_lower(k), to_h(v, &block)]
          else
            [camel_case_lower(k), v]
          end
        end
      end

      # Convert a string to snake case
      def self.underscore str
        str.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end

      # Convert a string to camel case
      def self.camel_case_lower sym
        sym.to_s.split('_').inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join.to_sym
      end

    end

    # A class that can create a site.identity_manager singleton for you
    class Extension

      def execute site
        site.identity_manager = IdentityManager.new site
      end

    end

    # A class that can look up a contributor from searchisko, given a
    # prototype contributor
    class IdentityManager

      def initialize site
        @site = site
        if (site.cache.nil?)
          site.send('cache=', Aweplug::Cache::YamlFileCache.new)
        end
        @cache = {}
      end

      # Get a contributor from searchisko, given a prototype
      # If no result is found, or if the protoype matches more than
      # one contributor, the prototype object will be returned, and a
      # message logged to the console
      def get(prototype)
        string_proto = prototype.to_s
        if @cache.has_key? prototype.to_s
          @cache[string_proto]
        else
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url,
                                                        :authenticate => false,
                                                        :cache => @site.cache,
                                                        :logger => @site.profile == 'development',
                                                        :searchisko_warnings => @site.searchisko_warnings})
          query = prototype.to_query
          hits = JSON.load((searchisko.get("search?sys_type=contributor_profile&field=_source&#{query}")).body)['hits']
          if hits['hits'].length == 1
            json = hits['hits'][0]['_source']
            @cache[string_proto] = prototype.merge(Contributor.parse(json))
          elsif hits['hits'].length > 1
            contributors = hits['hits'].collect {|h| h['_source']['id']}.join(', ')
            puts "#{query} matches more than one contributor: #{contributors}"
            @cache[string_proto] = prototype
          else
            puts "#{query} does not match any contributors"
            @cache[string_proto] = prototype
          end
        end
      end
    end
  end
end

