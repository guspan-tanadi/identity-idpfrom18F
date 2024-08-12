require 'rails_helper'

RSpec.describe Users::PersonalKeysController do
  describe '#show' do
    context 'when user signed in but user_session[:personal_key] is not present' do
      it 'redirects to account_url' do
        stub_sign_in

        get :show

        expect(response).to redirect_to(account_url)
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'tracks the page visit when there is a personal key in the user session' do
      stub_sign_in
      controller.user_session[:personal_key] = 'foo'
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event('Personal key viewed', personal_key_present: true)
    end

    it 'tracks the page visit when there is no personal key in the user session' do
      stub_sign_in
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event('Personal key viewed', personal_key_present: false)
    end

    it 'does not generate a new personal key to avoid CSRF attacks' do
      stub_sign_in

      generator = instance_double(PersonalKeyGenerator)
      allow(PersonalKeyGenerator).to receive(:new).
        with(subject.current_user).and_return(generator)

      expect(generator).to_not receive(:create)

      get :show
    end
  end

  describe '#update' do
    context 'user does not need to reactivate account' do
      it 'redirects to the profile page' do
        stub_sign_in

        patch :update

        expect(response).to redirect_to account_url
        expect(flash[:success]).to eq(t('account.personal_key.reset_success'))
      end
    end

    context 'user needs to reactive account' do
      it 'redirects to the sign up completed url for ial 1' do
        controller.session[:sp] = {
          issuer: create(:service_provider).issuer,
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        }

        user = create(:user, :fully_registered)
        create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        user.active_profile.deactivate(:password_reset)
        sign_in user

        patch :update

        expect(response).to redirect_to sign_up_completed_url
        expect(flash[:success]).to be_nil
      end

      it 'redirects to the reactivate account url for ial 2' do
        controller.session[:sp] = {
          issuer: create(:service_provider).issuer,
          acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        }

        user = create(:user, :fully_registered)
        create(:profile, :active, :verified, user: user, pii: { first_name: 'Jane' })
        user.active_profile.deactivate(:password_reset)
        sign_in user

        patch :update

        expect(response).to redirect_to reactivate_account_url
        expect(flash[:success]).to be_nil
      end
    end

    it 'deletes user_session[:personal_key]' do
      stub_sign_in
      controller.user_session[:personal_key] = 'foo'

      post :update

      expect(controller.user_session[:personal_key]).to be_nil
    end

    it 'tracks CSRF errors' do
      stub_sign_in
      stub_analytics
      allow(controller).to receive(:update).and_raise(ActionController::InvalidAuthenticityToken)

      post :update

      expect(@analytics).to have_logged_event(
        'Invalid Authenticity Token',
        controller: 'users/personal_keys#update',
        user_signed_in: true,
      )
      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end
  end
end
