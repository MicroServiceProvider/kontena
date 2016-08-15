module OAuth2Api
  class CallbackApi < Roda
    include RequestHelpers

    def logger
      @logger ||= Server.logger
    end

    route do |r|
      r.get do
        params = request.params

        if params['error']
          halt_request(502, "The authorization server returned an error: #{params['error']} #{params['error_description']} #{params['error_uri']}") and return
        end

        unless params['state']
          halt_request(400, 'invalid_request') and return
        end

        state = AuthorizationRequest.find_and_invalidate(params['state'])
        unless state
          halt_request(400, 'invalid_request') and return
        end

        token_data = AuthProvider.get_token(params['code'])

        if token_data && token_data.kind_of?(Hash) && token_data.has_key?('access_token')
          logger.debug "Retrieving user data from authentication provider"
          user_data = AuthProvider.get_userinfo(token_data['access_token'])
          logger.debug "Received user data: #{user_data.inspect}"
        else
          user_data = nil
        end

        unless user_data
          halt_request(400, 'Authentication failed')
        end

        if state.user
          state.user.invite_code = nil
          state.user.external_id = user_data[:id]
          state.user.save
        end

        user = state.user || User.where(external_id: user_data[:id]).first

        # If no existing user is found, create a new local regular user
        if user.nil? && (User.count == 0 || (User.count == 1 && User.first.email == 'admin'))
          user = User.create(
            external_id: user_data[:id],
            email: user_data[:email],
            name: user_data[:username]
          )
          user.roles << Role.master_admin
        end

        unless user
          halt_request(403, 'Access denid')
        end

        if token_data['expires_at']
          expires_at = Time.at(token_data['expires_at'])
        elsif token_data['expires_in'].to_i > 0
          expires_at = Time.now.utc + token_data['expires_in'].to_i
        else
          expires_at = nil
        end

        task = AccessTokens::Create.run(
          user: user,
          token: token_data['access_token'],
          refresh_token: token_data['refresh_token'],
          expires_at: expires_at,
          refreshable: !token_data['refresh_token'].nil?,
          scope: token_data['scope'] || AuthProvider.authenticate_scope
        )

        if task.success?
          external_access_token = task.result
        else
          logger.debug "Could not create external access token: #{task.errors.message.inspect}"
          halt_request(500, 'server_error')
          return
        end

        # Clean up user's old access tokens
        user.access_tokens.each do |at|
          if at.expired? || at.deleted_at || (!at.internal? && at.id != external_access_token.id)
            at.destroy
          end
        end

        task = AccessTokens::Create.run(
          user: user,
          scope: 'user',
          expires_in: 7200
        )

        if task.success?
          access_token = task.result
          redirect_uri = URI.parse(state.redirect_uri)
          redirect_uri.query = access_token.to_query
          logger.debug "Callback complete, redirecting to #{state.redirect_uri}"
          request.redirect(redirect_uri.to_s)
        else
          logger.debug "Could not create internal access token: #{task.errors.message.inspect}"
          halt_request(500, 'server_error')
        end
      end
    end
  end
end