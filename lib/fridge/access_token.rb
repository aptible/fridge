require 'jwt'

module Fridge
  class AccessToken
    attr_accessor :id, :issuer, :subject, :scope, :expires_at, :jwt

    # rubocop:disable MethodLength
    def initialize(jwt_or_options = nil)
      options = case jwt_or_options
                when String
                  self.jwt = jwt_or_options
                  validate_public_key!
                  decode_and_verify(jwt_or_options)
                when Hash then jwt_or_options
                else {}
                end
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
    # rubocop:enable MethodLength

    def to_s
      serialize
    end

    def serialize
      return jwt if jwt
      validate_parameters!
      validate_private_key!
      encode_and_sign
    end

    def encode_and_sign
      JWT.encode({
        id: id,
        iss: issuer,
        sub: subject,
        scope: scope,
        exp: expires_at.to_i
      }, private_key, algorithm)
    rescue
      raise SerializationError, 'Invalid private key or signing algorithm'
    end

    def decode_and_verify(jwt)
      hash = JWT.decode(jwt, public_key)
      {
        id: hash['id'],
        issuer: hash['iss'],
        subject: hash['sub'],
        scope: hash['scope'],
        expires_at: Time.at(hash['exp'])
      }
      rescue JWT::DecodeError
        raise InvalidToken, 'Invalid access token'
    end

    def valid?
      !expired?
    end

    def expired?
      expires_at.nil? || expires_at < Time.now
    end

    def private_key
      return unless config.private_key
      @private_key ||= OpenSSL::PKey::RSA.new(config.private_key)
    rescue
      nil
    end

    def public_key
      if config.private_key
        @public_key ||= OpenSSL::PKey::RSA.new(config.private_key).public_key
      elsif config.public_key
        @public_key ||= OpenSSL::PKey::RSA.new(config.public_key)
      end
    rescue
      nil
    end

    def algorithm
      config.signing_algorithm
    end

    def config
      Fridge.configuration
    end

    protected

    def validate_parameters!
      [:subject, :expires_at].each do |attribute|
        unless send(attribute)
          fail SerializationError, "Missing attribute: #{attribute}"
        end
      end
    end

    def validate_private_key!
      fail SerializationError, 'No private key configured' unless private_key
    end

    def validate_public_key!
      fail SerializationError, 'No public key configured' unless public_key
    end
  end
end
