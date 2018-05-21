require 'jwt'

module Fridge
  class AccessToken
    attr_accessor :id, :issuer, :subject, :scope, :expires_at, :actor,
                  :jwt, :attributes

    def initialize(jwt_or_options = nil)
      options = case jwt_or_options
                when String
                  self.jwt = jwt_or_options
                  validate_public_key!
                  decode_and_verify(jwt_or_options)
                when Hash then jwt_or_options
                else {}
                end

      [:id, :issuer, :subject, :scope, :expires_at, :actor].each do |key|
        send "#{key}=", options.delete(key)
      end
      self.attributes = options
    end

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
      h = {}
      [:id, :issuer, :subject, :scope, :expires_at, :actor].each do |key|
        h[key] = send(key)
      end
      h.merge!(attributes)
      h = encode_for_jwt(h)
      JWT.encode(h, private_key, algorithm)
    rescue
      raise SerializationError, 'Invalid private key or signing algorithm'
    end

    def decode_and_verify(jwt)
      payload, _header = JWT.decode(jwt, public_key, true, algorithm: algorithm)
      decode_from_jwt(payload)
    rescue JWT::ExpiredSignature => e
      raise ExpiredToken, e.message
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    def downgrade
      self.scope = 'read'
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

    def method_missing(method, *args, &block)
      if attributes.key?(method)
        attributes[method]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      attributes.key?(method) || super
    end

    def validate_parameters!
      [:subject, :expires_at].each do |attribute|
        next if send(attribute)
        raise SerializationError, "Missing attribute: #{attribute}"
      end
    end

    def validate_private_key!
      raise SerializationError, 'No private key configured' unless private_key
    end

    def validate_public_key!
      raise SerializationError, 'No public key configured' unless public_key
    end

    # Internally, we use "subject" to refer to "sub", and so on. We also
    # represent some objects (expiry) differently. These functions do the
    # mapping from Fridge to JWT and vice-versa.

    def encode_for_jwt(hash)
      hash = hash.dup

      out = {
        id: hash.delete(:id),
        iss: hash.delete(:issuer),
        sub: hash.delete(:subject),
        scope: hash.delete(:scope)
      }.delete_if { |_, v| v.nil? }

      # Unfortunately, nil.to_i returns 0, which means we can't
      # easily clean out exp if we include it although it wasn't passed
      # in like we do for other keys. So, we only include it if it's
      # actually passed in and non-nil. Either way, we delete the keys.
      hash.delete(:expires_at).tap { |e| out[:exp] = e.to_i if e }
      hash.delete(:actor).tap { |a| out[:act] = encode_for_jwt(a) if a }

      # Extra attributes passed through as-is
      out.merge!(hash)

      out
    end

    def decode_from_jwt(hash)
      hash = hash.dup

      out = {
        id: hash.delete('id'),
        issuer: hash.delete('iss'),
        subject: hash.delete('sub'),
        scope: hash.delete('scope')
      }.delete_if { |_, v| v.nil? }

      hash.delete('exp').tap { |e| out[:expires_at] = Time.at(e) if e }
      hash.delete('act').tap { |a| out[:actor] = decode_from_jwt(a) if a }

      # Extra attributes
      hash.delete_if { |_, v| v.nil? }
      hash = Hash[hash.map { |k, v| [k.to_sym, v] }]
      out.merge!(hash)

      out
    end
  end
end
