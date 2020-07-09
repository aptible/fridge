module Rails
  class App
    def env_config
      {}
    end

    def routes
      return @routes if defined?(@routes)

      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw do
        resources :posts
      end
      @routes
    end
  end

  def self.application
    @application ||= App.new
  end
end
