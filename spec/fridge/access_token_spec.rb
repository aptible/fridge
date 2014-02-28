require 'spec_helper'

describe Fridge::AccessToken do
  describe '#initialize' do
    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) { OpenSSL::PKey::RSA.new(private_key.public_key) }

    before { Fridge.configuration.public_key = public_key.to_s }

    it 'should accept a hash' do
      access_token = described_class.new(id: 'foobar')
      expect(access_token.id).to eq 'foobar'
    end

    it 'should accept a JWT' do
      jwt = JWT.encode({ id: 'foobar', exp: 0 }, private_key, 'RS512')
      access_token = described_class.new(jwt)
      expect(access_token.id).to eq 'foobar'
    end

    it 'should raise an error on an invalid JWT' do
      expect { described_class.new('foobar') }.to raise_error
    end

    it 'should raise an error on an incorrectly signed JWT' do
      jwt = JWT.encode({ id: 'foobar' }, OpenSSL::PKey::RSA.new(1024), 'RS512')
      expect { described_class.new(jwt) }.to raise_error Fridge::InvalidToken
    end
  end

  describe '#serialize' do
    let(:options) do
      {
        id: SecureRandom.uuid,
        issuer: 'https://auth.aptible.com',
        subject: "https://auth.aptible.com/users/#{SecureRandom.uuid}",
        scope: 'read',
        expires_at: Time.now + 3600
      }
    end

    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) { OpenSSL::PKey::RSA.new(private_key.public_key) }

    before { Fridge.configuration.private_key = private_key.to_s }

    subject { described_class.new(options) }

    it 'should return a JWT comprised of token attributes' do
      expect(subject.serialize).to eq JWT.encode({
        id: subject.id,
        iss: subject.issuer,
        sub: subject.subject,
        scope: subject.scope,
        exp: subject.expires_at.to_i
      }, private_key, 'RS512')
    end

    it 'should be verifiable with the application public key' do
      expect { JWT.decode(subject.serialize, public_key) }.not_to raise_error
    end

    it 'should be tamper-resistant' do
      header, _, signature = subject.serialize.split('.')
      tampered_claim = JWT.base64url_encode({ foo: 'bar' }.to_json)
      tampered_token = [header, tampered_claim, signature].join('.')

      expect do
        JWT.decode(tampered_token, public_key)
      end.to raise_error JWT::DecodeError
    end

    it 'should represent :exp in seconds since the epoch' do
      hash = JWT.decode(subject.serialize, public_key)
      expect(hash['exp']).to be_a Fixnum
    end

    it 'should be deterministic' do
      expect(subject.serialize).to eq subject.serialize
    end

    it 'should complement #initialize' do
      copy = described_class.new(subject.serialize)
      expect(copy.subject).to eq subject.subject
      expect(copy.expires_at.to_i).to eq subject.expires_at.to_i
      expect(copy.scope).to eq subject.scope
    end

    it 'should include custom attributes' do
      subject = described_class.new(options.merge(foo: 'bar'))
      copy = described_class.new(subject.serialize)

      expect(copy.attributes[:foo]).to eq 'bar'
      expect(copy.foo).to eq 'bar'
    end

    it 'should raise an error if required attributes are missing' do
      subject.subject = nil
      expect { subject.serialize }.to raise_error Fridge::SerializationError
    end
  end

  describe '#expired?' do
    it 'should return true if the access token has expired' do
      subject.stub(:expires_at) { Time.now - 3600 }
      expect(subject).to be_expired
    end

    it 'should return true if the access token has no expiration set' do
      subject.stub(:expires_at) { nil }
      expect(subject).to be_expired
    end

    it 'should return false otherwise' do
      subject.stub(:expires_at) { Time.now + 3600 }
      expect(subject).not_to be_expired
    end
  end
end
