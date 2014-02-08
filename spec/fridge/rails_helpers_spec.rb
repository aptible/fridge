require 'spec_helper'
require 'fixtures/app'
require 'fixtures/controller'
require 'rspec/rails'

# http://say26.com/rspec-testing-controllers-outside-of-a-rails-application
describe Controller, type: :controller do
  context Fridge::RailsHelpers do
    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
    let(:public_key) { OpenSSL::PKey::RSA.new(private_key.public_key) }

    let(:options) do
      {
        subject: "https://auth.aptible.com/users/#{SecureRandom.uuid}",
        expires_at: Time.now + 3600
      }
    end
    let(:access_token) { Fridge::AccessToken.new(options) }

    let(:cookies) { controller.send(:cookies) }

    before { Fridge.configuration.private_key = private_key.to_s }
    before { Fridge.configuration.public_key = public_key.to_s }

    describe '#bearer_token' do
      it 'returns the bearer token from the Authorization: header' do
        request.env['HTTP_AUTHORIZATION'] = 'Bearer foobar'
        expect(controller.bearer_token).to eq 'foobar'
      end

      it 'returns nil in the absence of an Authorization: header' do
        request.env['HTTP_AUTHORIZATION'] = nil
        expect(controller.bearer_token).to be_nil
      end
    end

    describe '#token_subject' do
      it 'returns the subject encoded in the token' do
        controller.stub(:current_token) { access_token }
        expect(controller.token_subject).to eq access_token.subject
      end

      it 'returns nil if no token is present' do
        controller.stub(:current_token) { nil }
        expect(controller.token_subject).to be_nil
      end
    end

    describe '#token_scope' do
      it 'returns the scope encoded in the token' do
        controller.stub(:current_token) { access_token }
        expect(controller.token_scope).to eq access_token.scope
      end

      it 'returns nil if no token is present' do
        controller.stub(:current_token) { nil }
        expect(controller.token_scope).to be_nil
      end
    end

    describe '#current_token' do
      before { controller.stub(:bearer_token) { access_token.serialize } }

      it 'should raise an error if the token is not a valid JWT' do
        controller.stub(:bearer_token) { 'foobar' }
        expect { controller.current_token }.to raise_error Fridge::InvalidToken
      end

      it 'should raise an error if the token has expired' do
        access_token.expires_at = Time.now - 3600
        expect { controller.current_token }.to raise_error Fridge::InvalidToken
      end

      it 'should raise an error if custom validation fails' do
        Fridge.configuration.validator = -> (token) { false }
        expect { controller.current_token }.to raise_error Fridge::InvalidToken
      end

      it 'should not raise an error if a valid token is passed' do
        expect { controller.current_token }.not_to raise_error
      end

      it 'should return the token if a valid token is passed' do
        expect(controller.current_token.id).to eq access_token.id
      end
    end

    describe '#session_subject' do
      it 'returns the subject encoded in the session' do
        controller.stub(:session_token) { access_token }
        expect(controller.session_subject).to eq access_token.subject
      end

      it 'returns nil if no session is present' do
        controller.stub(:session_token) { nil }
        expect(controller.session_subject).to be_nil
      end
    end

    describe '#session_token' do
      it 'should delete all cookies on error' do
        cookies[:session_token] = 'foobar'
        controller.session_token
        expect(cookies.deleted?(:session_token, domain: :all)).to be_true
      end

      it 'should return nil on error' do
        cookies[:session_token] = 'foobar'
        expect(controller.session_token).to be_nil
      end

      it 'should return the token stored in :session_token' do
        cookies[:session_token] = access_token.serialize
        expect(controller.session_token.id).to eq access_token.id
      end
    end

    describe '#store_session_token' do
      it 'should set a session cookie' do
        Rails.stub_chain(:env, :development?) { false }
        controller.store_session_token(access_token)
        expect(cookies[:session_token]).to eq access_token.serialize
      end
    end
  end
end
