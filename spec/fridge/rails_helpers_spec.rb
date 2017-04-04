require 'spec_helper'
require 'fixtures/app'
require 'fixtures/controller'
require 'rspec/rails'

# http://say26.com/rspec-testing-controllers-outside-of-a-rails-application
describe Controller, type: :controller do
  context Fridge::RailsHelpers do
    let(:organization_url) do
      "https://auth.aptible.com/users/#{SecureRandom.uuid}"
    end
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
        Fridge.configuration.validator = ->(_) { false }
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
        cookies[:fridge_session] = 'foobar'
        controller.session_token
        expect(cookies.deleted?(:fridge_session, domain: :all)).to be true
      end

      it 'should return nil on error' do
        cookies[:fridge_session] = 'foobar'
        expect(controller.session_token).to be_nil
      end

      it 'should return the token stored in :fridge_session' do
        cookies[:fridge_session] = access_token.serialize
        expect(controller.session_token.id).to eq access_token.id
      end

      context 'with a non-:read scope' do
        before { options.merge!(scope: 'manage') }

        it 'should downgrade the token' do
          cookies[:fridge_session] = access_token.serialize
          expect(controller.session_token.scope).to eq 'read'
        end

        it 'should not change the validity of a token' do
          cookies[:fridge_session] = access_token.serialize
          expect(controller.session_token).to be_valid
        end
      end
    end

    describe '#validate_token' do
      it 'should return false if the token is invalid' do
        Fridge.configuration.validator = ->(_) { false }
        expect(controller.validate_token(access_token)).to be false
      end

      it 'should return false if the token validator fails' do
        Fridge.configuration.validator = ->(_) { raise 'Foobar' }
        expect(controller.validate_token(access_token)).to be false
      end

      it 'should return the token if valid' do
        Fridge.configuration.validator = ->(_) { true }
        expect(controller.validate_token(access_token)).to eq access_token
      end
    end

    describe '#validate_token' do
      it 'should raise an exception if the token is invalid' do
        Fridge.configuration.validator = ->(_) { false }
        expect { controller.validate_token!(access_token) }.to raise_error
      end

      it 'should return the token if valid' do
        Fridge.configuration.validator = ->(_) { true }
        expect(controller.validate_token!(access_token)).to eq access_token
      end
    end

    describe '#sessionize_token' do
      it 'should set a session cookie' do
        Rails.stub_chain(:env, :development?) { false }
        controller.sessionize_token(access_token)
        expect(cookies[:fridge_session]).to eq access_token.serialize
      end
    end

    describe '#fridge_cookie_name' do
      it 'is configurable' do
        Fridge.configuration.cookie_name = 'foobar'
        expect(controller.fridge_cookie_name).to eq 'foobar'
      end
    end

    describe '#write_shared_cookie' do
      before { Rails.stub_chain(:env, :development?) { false } }

      it 'should save cookie' do
        controller.write_shared_cookie(:organization_url, organization_url)
        expect(cookies[:organization_url]).to eq organization_url
      end
    end

    describe '#read_shared_cookie' do
      it 'should read cookie' do
        cookies[:organization_url] = { value: organization_url }
        expect(controller.read_shared_cookie(:organization_url)).to(
          eq organization_url
        )
      end
    end

    describe '#delete_shared_cookie' do
      before { Rails.stub_chain(:env, :development?) { false } }

      it 'should delete cookie' do
        controller.write_shared_cookie(:organization_url, organization_url)
        controller.delete_shared_cookie(:organization_url)
        expect(cookies[:organization_url]).to be_nil
      end
    end

    describe '#fridge_cookie_options' do
      before { Rails.stub_chain(:env, :development?) { false } }

      it 'are configurable' do
        Fridge.configuration.cookie_options = { foobar: true }
        options = controller.fridge_cookie_options
        expect(options[:domain]).to eq :all
        expect(options[:foobar]).to eq true
      end
    end
  end
end
