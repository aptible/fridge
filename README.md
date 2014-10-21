# ![](https://raw.github.com/aptible/straptible/master/lib/straptible/rails/templates/public.api/icon-60px.png) Fridge

[![Gem Version](https://badge.fury.io/rb/fridge.png)](https://rubygems.org/gems/fridge)
[![Build Status](https://travis-ci.org/aptible/fridge.png?branch=master)](https://travis-ci.org/aptible/fridge)
[![Dependency Status](https://gemnasium.com/aptible/fridge.png)](https://gemnasium.com/aptible/fridge)

Token validation for distributed resource servers.

## Installation

Add the following line to your application's Gemfile.

    gem 'fridge'

And then run `bundle install`.

## Usage

### Configuration

| Parameter | Description | Possible Values |
| --------- | ----------- | --------------- |
| `private_key` | Private token signing key | A PEM-formatted key |
| `public_key` | Public token verification key (the private key's complement) | A PEM-formatted key |
| `signing_algorithm` | Algorithm to use for sigining and verification | `RS512`, `RS256` |
| `validator` | A lambda used to perform custom validation of tokens | Any `Proc` |

Resource servers must configure a public key corresponding to an authorization server, in order to verify tokens issued by that server. Authorization servers must configure a private key.

By default, public key-verified tokens are considered valid if and only iff they have not expired (i.e., `expires_at > Time.now`). However, some applications may want to perform additional validations. (For example, an authorization server may allow online revocation of tokens before their natural expiration, and need to check the current ). This is possible by configuring a custom validator:

```ruby
Fridge.configure do |config|
  config.validator = lambda do |access_token|
    token = Token.find_by(id: access_token.id)
    token && !token.revoked?
  end
end
```

The validator will be called with a single argument, the `Fridge::AccessToken` instance.

### Integrating with Fridge from a resource server

From any of your controllers, you may access the following methods:

* `current_token`: The `Fridge::AccessToken` passed via `Authorization` header.
* `token_subject`: The subject (`:sub`) of the current token.
* `token_scope`: The scope (`:scope`) of the current token.
* `session_token`: The `Fridge::AccessToken` stored in the user agent's cookies.
* `session_subject`: The subject (`:sub`) of the current session token.


### Integrating with Fridge from an authorization server

A Fridge access token may be constructed a la the following example:

```ruby
access_token = Fridge::AccessToken.new(
  id: '0f1aa5ce-6e93-4812-b3fc-3b7f7b685991',
  subject: 'https://auth.aptible.com/users/e600a449-b308-4162-ac28-8a2769ad3f05',
  expires_at: 1.hour.from_now
)
```

The only required hash parameters are `:subject` and `:expires_at`. Additionally, you may specify `:id`, `:scope` and `issuer`. To set this token in a cookie that's readable across your entire domain, you may invoke the following command from any Rails controller:

```ruby
store_session_cookie(access_token)
```

## Contributing

1. Fork the project.
1. Commit your changes, with specs.
1. Ensure that your code passes specs (`rake spec`) and meets Aptible's Ruby style guide (`rake rubocop`).
1. Create a new pull request on GitHub.

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com) and contributors.

[<img src="https://s.gravatar.com/avatar/f7790b867ae619ae0496460aa28c5861?s=60" style="border-radius: 50%;" alt="@fancyremarker" />](https://github.com/fancyremarker)
