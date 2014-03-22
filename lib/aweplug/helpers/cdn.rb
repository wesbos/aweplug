require 'digest'
require 'yaml'

module Aweplug
  module Helpers
    # CDN will take the details of a file passed to the version method
    # If necessary, if the file has changed since the last time version
    # was called for that method, it will generate a copy of the file in
    # _tmp/cdn with new file name, and return that file name
    class CDN

      TMP_DIR = Pathname.new("_tmp").join("cdn")
      DIR = Pathname.new("_cdn")
      CONTROL = DIR.join("cdn.yml")
      EXPIRES_FILE = DIR.join("cdn_expires.htaccess")

      def initialize(ctx_path)
        @tmp_dir = TMP_DIR.join ctx_path
        FileUtils.mkdir_p(File.dirname(CONTROL))
        FileUtils.mkdir_p(@tmp_dir)
        if File.exists? EXPIRES_FILE
          FileUtils.cp(EXPIRES_FILE, @tmp_dir.join(".htaccess"))
        end
      end

      def version(name, ext, content)
        id = name + ext
        yml = YAML::Store.new CONTROL
        yml.transaction do
          yml[id] ||= { "build_no" => 0 }
          md5sum = Digest::MD5.hexdigest(content)
          if yml[id]["md5sum"] != md5sum
            yml[id]["md5sum"] = md5sum
            build_no = yml[id]["build_no"] += 1
            File.open(@tmp_dir.join(name + "-" + build_no.to_s + ext), 'w') { |file| file.write(content) }
          end
          name + "-" + yml[id]["build_no"].to_s + ext
        end
      end
   
    end
  end
end
