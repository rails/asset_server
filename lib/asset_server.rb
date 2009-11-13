require 'digest/md5'
require 'time'

# match "/stylesheets/all.js", :to => Assets::Server.new("#{Rails.root}/app/assets/stylesheets/**/*")
# match "/javascript", :to => Assets::Server.new("#{Rails.root}/app/assets/javascript")
# match "/images", :to => Assets::Server.new("#{Rails.root}/app/assets/images")


module Assets
  class BundleServer
    YEAR_IN_SECONDS = 31540000
    
    def initialize(*paths)
      @sources = paths.map { |path| Dir[path] }.flatten
    end

    def last_modified_source
      @sources.collect { |file| File.mtime(file) }.sort.last
    end

    def call(env)
      rebundle if source_changed?

      if not_modified?(env) || etag_match?(env)
        not_modified_response(env)
      else
        ok_response(env)
      end
    end

    private
      def source_changed?
        true
      end

      def rebundle
        @source                 = concate_source
        @etag                   = compute_quoted_md5
        @previous_last_modified = last_modified_source
      end


      def not_modified?(env)
        env["HTTP_IF_MODIFIED_SINCE"] == @previous_last_modified.httpdate
      end
      
      def etag_match?(env)
        env["HTTP_IF_NONE_MATCH"] == @etag
      end

      def not_modified_response(env)
        [ 304, headers(env), [] ]
      end
      
      def ok_response(env)
        [ 200, headers(env), [@source] ]
      end

      
      def headers(env)
        Hash.new.tap do |headers|
          headers["Content-Type"]   = "text/javascript"
          headers["Content-Length"] = @source.size.to_s

          headers["Cache-Control"]  = "public, must-revalidate"
          headers["Last-Modified"]  = @previous_last_modified.httpdate
          headers["ETag"]           = @etag

          if env["QUERY_STRING"] == self.md5
            headers["Cache-Control"] << ", max-age=#{YEAR_IN_SECONDS}"
          end
        end
      end
    
      def concate_source
        @sources.collect { |file| File.read(file) }.join("\n\n")        
      end
      
      def compute_quoted_md5
        %("#{Digest::MD5.hexdigest(@source)}")
      end    
  end
end