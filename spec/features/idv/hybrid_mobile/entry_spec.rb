require 'rails_helper'

RSpec.feature 'mobile hybrid flow entry', :js do
  include IdvStepHelper

  let(:link_sent_via_sms) do
    link = nil

    # Intercept the link being SMS'd to the user.
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      link = config[:link]
      impl.call(**config)
    end

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_hybrid_handoff_step
    click_send_link

    link
  end

  let(:link_to_visit) { link_sent_via_sms }

  context 'valid link' do
    before do
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    end

    it 'puts the user on the document capture page' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        # Should have redirected to the actual doc capture url
        expect(current_url).to eql(idv_hybrid_mobile_document_capture_url)

        # Confirm that we end up on the LN / Mock page even if we try to
        # go to the Socure one.
        visit idv_hybrid_mobile_socure_document_capture_url
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
      end
    end

    context 'when socure is the doc auth vendor' do
      before do
        allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket)
          .and_return(Idp::Constants::Vendors::SOCURE)
        stub_docv_document_request
      end

      it 'puts the user on the socure document capture page' do
        expect(link_to_visit).to be

        Capybara.using_session('mobile') do
          visit link_to_visit
          # Should have redirected to the actual doc capture url
          expect(current_url).to eql(idv_hybrid_mobile_socure_document_capture_url)

          # Confirm that we end up on the LN / Mock page even if we try to
          # go to the Socure one.
          visit idv_hybrid_mobile_document_capture_url
          expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_url)
        end
      end
    end
  end

  context 'old link' do
    let(:link_to_visit) do
      # Edit in the old link, which should redirect to the new controller
      uri = URI.parse(link_sent_via_sms)
      uri.path = '/verify/capture-doc'
      uri.to_s
    end

    it 'puts the user on the new document capture page' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        # Should have redirected to the actual doc capture url
        expect(current_url).to eql(idv_hybrid_mobile_document_capture_url)
      end
    end
  end

  context 'invalid link' do
    let(:link_to_visit) do
      # Put an invalid document-capture-session in the URL
      uri = URI.parse(link_sent_via_sms)
      query = Rack::Utils.parse_query(uri.query)
      query['document-capture-session'] = SecureRandom.uuid
      uri.query = Rack::Utils.build_query(query)
      uri.to_s
    end

    it 'redirects to the root' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        expect(current_url).to eql(root_url)
      end
    end
  end
end
