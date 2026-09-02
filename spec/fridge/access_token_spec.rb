# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Fridge::AccessToken do
  describe '#initialize' do
    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) { OpenSSL::PKey::RSA.new(private_key.public_key) }

    before { Fridge.configuration.public_key = public_key.to_s }

    it 'accepts a hash' do
      access_token = described_class.new(id: 'foobar')
      expect(access_token.id).to eq 'foobar'
    end

    it 'accepts a JWT' do
      jwt = JWT.encode(
        { id: 'foobar', exp: Time.now.to_i + 10 },
        private_key, 'RS512'
      )
      access_token = described_class.new(jwt)
      expect(access_token.id).to eq 'foobar'
    end

    it 'raises an error on an invalid JWT' do
      expect { described_class.new('foobar') }
        .to raise_error Fridge::InvalidToken
    end

    it 'raises an error on an incorrectly signed JWT' do
      jwt = JWT.encode({ id: 'foobar' }, OpenSSL::PKey::RSA.new(1024), 'RS512')
      expect { described_class.new(jwt) }.to raise_error Fridge::InvalidToken
    end

    it 'raises an error on an expired JWT' do
      jwt = JWT.encode(
        { id: 'foobar', exp: Time.now.to_i - 10 },
        private_key, 'RS512'
      )
      expect { described_class.new(jwt) }.to raise_error(Fridge::ExpiredToken)
    end

    # http://bit.ly/jwt-none-vulnerability
    it 'raises an error with { "alg": "none" }' do
      jwt = "#{Base64.encode64({ typ: 'JWT', alg: 'none' }.to_json).chomp}." \
            "#{Base64.encode64({ id: 'foobar' }.to_json).chomp}"
      expect(JWT.decode(jwt, nil, false)[0]).to eq('id' => 'foobar')
      expect { described_class.new(jwt) }.to raise_error Fridge::InvalidToken
    end
  end

  describe '#serialize' do
    subject { described_class.new(options) }

    let(:options) do
      {
        id: SecureRandom.uuid,
        issuer: 'https://auth.aptible.com',
        subject: "https://auth.aptible.com/users/#{SecureRandom.uuid}",
        scope: 'read',
        expires_at: Time.zone.now + 3600
      }
    end

    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) { OpenSSL::PKey::RSA.new(private_key.public_key) }

    before { Fridge.configuration.private_key = private_key.to_s }

    it 'returns a JWT comprised of token attributes' do
      hash = {
        id: subject.id,
        iss: subject.issuer,
        sub: subject.subject,
        scope: subject.scope,
        exp: subject.expires_at.to_i
      }
      expect(subject.serialize).to eq JWT.encode(hash, private_key, 'RS512')
    end

    it 'is verifiable with the application public key' do
      expect { JWT.decode(subject.serialize, public_key, true, algorithm: 'RS512') }
        .not_to raise_error
    end

    it 'is tamper-resistant' do
      header, _, signature = subject.serialize.split('.')
      tampered_claim = JWT::Base64.url_encode({ foo: 'bar' }.to_json)
      tampered_token = [header, tampered_claim, signature].join('.')

      expect do
        JWT.decode(tampered_token, public_key, true, algorithm: 'RS512')
      end.to raise_error JWT::DecodeError
    end

    it 'represents :exp in seconds since the epoch' do
      hash, = JWT.decode(subject.serialize, public_key, true, algorithm: 'RS512')
      expect(hash['exp']).to be_a Integer
    end

    it 'is deterministic' do
      first = subject.serialize
      expect(subject.serialize).to eq first
    end

    it 'complements #initialize' do
      copy = described_class.new(subject.serialize)
      expect(copy.subject).to eq subject.subject
      expect(copy.expires_at.to_i).to eq subject.expires_at.to_i
      expect(copy.scope).to eq subject.scope
    end

    it 'includes custom attributes' do
      subject = described_class.new(options.merge(foo: 'bar'))
      copy = described_class.new(subject.serialize)

      expect(copy.attributes[:foo]).to eq 'bar'
      expect(copy.foo).to eq 'bar'
      expect(copy.respond_to?(:foo)).to be_truthy
      expect(copy.respond_to?(:bar)).to be_falsey
    end

    it 'raises an error if required attributes are missing' do
      subject.subject = nil
      expect { subject.serialize }.to raise_error Fridge::SerializationError
    end

    it 'encodes and decode :actor as :act' do
      # The `act` field can recursively encode additional
      # claims, so we check those too.
      actor = { subject: 'foo', username: 'test', actor: { subject: 'bar' } }
      subject = described_class.new(options.merge(actor: actor))

      # The JWT lib will return everything as strings, so we'll
      # test that, although eventually we'll want to see symbols back.
      actor_s = { 'sub' => 'foo', 'username' => 'test',
                  'act' => { 'sub' => 'bar' } }
      hash, = JWT.decode(subject.serialize, public_key, true, algorithm: 'RS512')
      expect(hash['act']).to eq(actor_s)

      # Now, check that we properly get symbols back
      new = described_class.new(subject.serialize)
      expect(new.actor).to eq(actor)
    end

    it 'is idempotent' do
      subject = described_class.new(options)
      first = subject.serialize
      expect(subject.serialize).to eq(first)
    end

    it 'is idempotent with an actor' do
      actor = { subject: 'foo', username: 'test', actor: { subject: 'bar' } }
      subject = described_class.new(options.merge(actor: actor))
      first = subject.serialize
      expect(subject.serialize).to eq(first)
    end
  end

  describe '#expired?' do
    it 'returns true if the access token has expired' do
      subject.stub(:expires_at) { Time.zone.now - 3600 }
      expect(subject).to be_expired
    end

    it 'returns true if the access token has no expiration set' do
      subject.stub(:expires_at) { nil }
      expect(subject).to be_expired
    end

    it 'returns false otherwise' do
      subject.stub(:expires_at) { Time.zone.now + 3600 }
      expect(subject).not_to be_expired
    end
  end

  describe '#downgrade' do
    it 'sets the token scope to :read' do
      expect { subject.downgrade }.to change(subject, :scope).to('read')
    end
  end
end
