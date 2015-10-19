require 'aweplug/cache'
require 'awestruct/util/exception_helper'
require 'uri/https'
require 'aweplug/helpers/searchisko'

module Aweplug
  module Helpers
    module Video
      module Helpers

        def render(video, default_snippet, snippet)
          if snippet
            path = snippet
          else
            path = default_snippet
          end
          begin
            if !File.exists?("#{site.dir}/_partials/#{path}")
              path = Pathname.new(File.dirname(__FILE__)).join(default_snippet)
              page.video = video
              Tilt.new(path.to_s).render(Object.new, :page => page, :site => site)
            else
              partial path, {:video => video, :parent => page}
            end
          rescue Exception => e
            ExceptionUtil.log_building_error e, page.source_path
            ExceptionUtil.marke_failed
          end
        end

        def add_video(video, product, push_to_searchisko)
          output_path = File.join '/video', video.provider, "#{video.id}.html"
          unless @site.pages.any? {|p| p.output_path == output_path}
            add_video_to_site video, output_path, @site
          end
          video.add_target_product product if product
          url = convert_url_to_key URI.parse video.url
          @site.videos[url.to_s] = video
          video
        end

        def send_video_to_searchisko(video, site, product, push_to_searchisko, cache)
          unless (payload = video.searchisko_payload).nil?
            unless  !push_to_searchisko || site.profile =~ /development/
              searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                              :authenticate => true, 
                                                              :searchisko_username => ENV['dcp_user'], 
                                                              :searchisko_password => ENV['dcp_password'], 
                                                              :cache => cache,
                                                              :logger => site.log_faraday,
                                                              :searchisko_warnings => site.searchisko_warnings})
              payload = payload.merge({:target_product => product}) unless product.nil?
              searchisko.push_content("jbossdeveloper_#{video.provider}", video.id, payload.to_json)
            end 
          end
        end

        def add_video_to_site(video, page_path, site)
          
          page = ::Awestruct::Page.new(site,
                                        ::Awestruct::Handlers::LayoutHandler.new(site,
                                        ::Awestruct::Handlers::TiltHandler.new(site,
                                          ::Aweplug::Handlers::SyntheticHandler.new(site, '', page_path))))
          page.layout = site.video_layout || 'video_page'
          page.output_path = page_path
          page.stale_output_callback = ->(p) { return (File.exist?(p.output_path) && File.mtime(__FILE__) > File.mtime(p.output_path)) }
          page.url = "#{site.base_url}/video/#{video.provider}/#{video.id}"
          page.send('title=', video.title)
          page.send('description=', video.description)
          page.send('video=', video)
          page.send('video_url=', video.url)
          site.pages << page 
        end

        # Public: Searches for the given video, by URL in the site.
        #
        # Returns true if the video is already in the site
        def site_include_video? site, url

        end

        # Public: Converts the url to correct form for site keys
        #
        # Returns the url to the site key form
        def convert_url_to_key url
          begin
            uri = URI.parse url
            uri.scheme = 'https' if uri.scheme == 'http'
            uri.to_s.freeze
          rescue
            url.to_s.freeze
          end
        end

      end
    end
  end
end

