require 'asset_server'

module Assets
  class Router
    def initialize(app)
      @app = app
    end

    Stylesheets = Assets::BundleServer.new("#{Rails.root}/public/stylesheets/**/*.css")
    Javascripts = Assets::BundleServer.new("#{Rails.root}/public/javascripts/**/*.js")  

    def call(env)
      if javascript_path?(env)
        Javascripts.call(env)
      elsif stylesheets_path?(env)
        Stylesheets.call(env)
      else
        @app.call(env)
      end
    end

    private
      def javascript_path?(env)
        env["PATH_INFO"] == "/javascripts/xall.js"
      end

      def stylesheets_path?(env)
        env["PATH_INFO"] == "/stylesheets/xall.css"
      end
  end
end
