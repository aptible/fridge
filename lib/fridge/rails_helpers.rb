module Fridge
  module RailsHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :write_shared_cookie, :fetch_shared_cookie,
                    :read_shared_cookie
    end

    def token_scope
      current_token.scope if current_token
    end

    def token_subject
      current_token.subject if current_token
    end

    def token_actor
      current_token.actor if current_token
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

    def session_actor
      session_token.actor if session_token
    end

    def session_token
      return unless session_cookie

      @session_token ||= AccessToken.new(session_cookie).tap do |token|
        validate_token!(token).downgrade
      end
    rescue StandardError
      clear_session_cookie
    end

    # Validates token, and returns the token, or nil
    def validate_token(access_token)
      validator = Fridge.configuration.validator
      validator.call(access_token) && access_token
    rescue StandardError
      false
    end

    # Validates token, and raises an exception if invalid
    def validate_token!(access_token)
      validator = Fridge.configuration.validator
      if validator.call(access_token)
        access_token
      else
        raise InvalidToken, 'Rejected by validator'
      end
    end

    def sessionize_token(access_token)
      # Ensure that any cookie-persisted tokens are read-only
      access_token.scope = 'read'

      jwt = access_token.serialize
      self.session_cookie = {
        value: jwt,
        expires: access_token.expires_at
      }.merge(fridge_cookie_options)
    end

    def session_cookie
      cookies[fridge_cookie_name]
    end

    def session_cookie=(cookie)
      cookies[fridge_cookie_name] = cookie
    end

    def clear_session_cookie
      cookies.delete fridge_cookie_name, domain: auth_domain
      nil
    end

    def write_shared_cookie(name, value, options = {})
      raise 'Can only write string cookie values' unless value.is_a?(String)

      cookies[name] = {
        value: value,
        expires: options[:expires] || 1.year.from_now
      }.merge(fridge_cookie_options)
    end

    def read_shared_cookie(name)
      cookies[name]
    end

    def fetch_shared_cookie(name)
      return read_shared_cookie(name) if read_shared_cookie(name)

      write_shared_cookie(yield)
    end

    def delete_shared_cookie(name)
      cookies.delete name, fridge_cookie_options.slice(:domain)
    end

    def fridge_cookie_name
      Fridge.configuration.cookie_name
    end

    def fridge_cookie_options
      secure = !Rails.env.development?
      options = { domain: auth_domain, secure: secure, httponly: true }
      options.merge(Fridge.configuration.cookie_options)
    end

    def auth_domain
      domain = URI.parse(Aptible::Auth.configuration.root_url).host

      # On localhost we fall back to the default setting b/c browsers won't set
      # cookies if localhost is named
      domain == 'localhost' ? :all : domain
    rescue StandardError
      'auth.aptible.com'
    end
  end
end
