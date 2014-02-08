module Fridge
  module RailsHelpers
    def token_scope
      current_token.scope if current_token
    end

    def token_subject
      current_token.subject if current_token
    end

    def current_token
      return unless bearer_token
      @current_token ||= AccessToken.new(bearer_token).tap do |token|
        validate_token!(token)
      end
    end

    def bearer_token
      header = request.env['HTTP_AUTHORIZATION']
      header.gsub(/^Bearer /, '') unless header.nil?
    end

    def session_subject
      session_token.subject if session_token
    end

    def session_token
      return unless cookies[:session_token]
      @session_token = AccessToken.new(cookies[:session_token]).tap do |token|
        validate_token!(token)
      end
    rescue
      clear_session_token
      @session_token = nil
    end

    def validate_token!(access_token)
      validator = Fridge.configuration.validator
      fail InvalidToken unless validator.call(access_token)
    end

    def store_session_token(access_token)
      # Ensure that any cookie-persisted tokens are read-only
      access_token.scope = 'read'

      jwt = access_token.serialize
      cookies[:session_token] = cookie_options.merge(
        value: jwt,
        expires_at: access_token.expires_at
      )
    end

    def clear_session_token
      cookies.delete :session_token, domain: :all
      nil
    end

    def cookie_options
      secure = !Rails.env.development?
      { domain: :all, secure: secure, httponly: true }
    end
  end
end
