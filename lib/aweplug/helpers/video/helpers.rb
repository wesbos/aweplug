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
          if !File.exists?("#{site.dir}/_partials/#{path}")
            path = Pathname.new(File.dirname(__FILE__)).join(default_snippet)
            page.video = video
            Tilt.new(path.to_s).render(Object.new, :page => page, :site => site)
          else
            partial path, {:video => video, :parent => page}
          end
        end

        def add_video(video, product, push_to_searchisko)
          output_path = File.join 'video', video.provider, "#{video.id}.html"
          unless @site.pages.any? {|p| p.output_path == output_path}
            add_video_to_site video, output_path, @site
            send_video_to_searchisko video, @site, product, push_to_searchisko
          end
          video
        end

        def send_video_to_searchisko(video, site, product, push_to_searchisko)
          unless (payload = video.searchisko_payload).nil?
            unless  !push_to_searchisko || site.profile =~ /development/
              searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                              :authenticate => true, 
                                                              :searchisko_username => ENV['dcp_user'], 
                                                              :searchisko_password => ENV['dcp_password'], 
                                                              :cache => site.cache,
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

      end
    end
  end
end

