require 'digest'
require 'yaml'

module Aweplug
  module Helpers
    # CDN will take the details of a file passed to the version method
    # If necessary, if the file has changed since the last time version
    # was called for that method, it will generate a copy of the file in
    # _tmp/cdn with new file name, and return that file name
    class CDN

      attr_accessor :control, :tmp_dir

      DIR = Pathname.new("_cdn")
      EXPIRES_FILE = DIR.join("cdn_expires.htaccess")
      ENV_PREFIX = ENV['cdn_prefix']

      def initialize(ctx_path, cdn_out_dir, version)
        @version = version
        @ctx_path = ctx_path
        unless ENV_PREFIX.nil?
          out_dir = Pathname.new(cdn_out_dir).join("cdn").join(ENV_PREFIX)
          control_dir = DIR.join(ENV_PREFIX)
        else
          out_dir = Pathname.new(cdn_out_dir).join("cdn")
          control_dir = DIR
        end
        @control = control_dir.join("cdn.yml")
        @tmp_dir = out_dir.join ctx_path
        FileUtils.mkdir_p(File.dirname(@control))
        FileUtils.mkdir_p(@tmp_dir)
        if File.exists? EXPIRES_FILE
          FileUtils.cp(EXPIRES_FILE, @tmp_dir.join(".htaccess"))
        end
      end

      def add(name, ext, content) 
        if @version
          version(name, ext, content)
        else
          File.open(@tmp_dir.join(name + ext), 'w') { |file| file.write(content) }
          name(name, ext)
        end
      end

      def version(name, ext, content)
        id = name + ext
        yml = YAML::Store.new @control
        yml.transaction do
          yml[id] ||= { "build_no" => 0 }
          md5sum = Digest::MD5.hexdigest(content)
          if yml[id]["md5sum"] != md5sum
            yml[id]["md5sum"] = md5sum
            build_no = yml[id]["build_no"] += 1
            File.open(@tmp_dir.join(name + "-" + build_no.to_s + ext), 'w') { |file| file.write(content) }
          end
          name(name, ext, yml[id]["build_no"].to_s)
        end
      end

      def name(name, ext, build_no = nil)
        unless build_no.nil?
          name = name + "-" + build_no
        end
        unless ENV_PREFIX.nil?
          Pathname.new(ENV_PREFIX).join(@ctx_path).join(name + ext).to_s
        else
          Pathname.new(@ctx_path).join(name + ext)
        end
      end
   
    end
  end
end
