require 'digest/md5'
require 'time'

module Assets
  class BundleServer
    def initialize(*paths)
      @sources = paths.map { |path| Dir[path] }.flatten
    end

    def last_modified_source
      @sources.collect { |file| File.mtime(file) }.sort.last
    end

    def call(env)
      return not_found_response if @sources.empty?
      
      rebundle if source_changed?

      if not_modified?(env) || etag_match?(env)
        not_modified_response(env)
      else
        ok_response(env)
      end
    end

    private
      def source_changed?
        @previous_last_modified.nil? ||
          (@previous_last_modified < last_modified_source)
      end

      def rebundle
        @source                 = concate_source
        @md5                    = compute_md5
        @etag                   = quoted_md5
        @previous_last_modified = last_modified_source
      end


      def not_found_response
        [ 404, { "Content-Type" => "text/plain", "Content-Length" => "9" }, [ "Not found" ] ]
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

          if env["QUERY_STRING"] == @md5
            headers["Cache-Control"] << ", max-age=#{1.year.to_i}"
          end
        end
      end
    
      def concate_source
        @sources.collect { |file| File.read(file) }.join("\n\n")        
      end
      
      def compute_md5
        Digest::MD5.hexdigest(@source)
      end    

      def quoted_md5
        %("#{@md5}")
      end    
  end
end