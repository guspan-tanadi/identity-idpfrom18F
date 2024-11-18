# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureController < ApplicationController
        include Idv::AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern
        include RenderConditionConcern
        include DocumentCaptureConcern

        check_or_render_not_found -> { IdentityConfig.store.socure_enabled }
        before_action :check_valid_document_capture_session, except: [:update]
        before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::SOCURE, true) }

        def show
          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('hybrid_mobile_socure_document_capture', :view, true)

          # document request
          document_request = DocAuth::Socure::Requests::DocumentRequest.new(
            redirect_url: idv_hybrid_mobile_socure_document_capture_update_url,
            language: I18n.locale,
          )
          document_response = document_request.fetch

          @document_request = document_request
          @document_response = document_response
          @url = document_response.dig(:data, :url)

          # placeholder until we get an error page for url not being present
          return redirect_to idv_unavailable_url if @url.nil?

          document_capture_session = DocumentCaptureSession.find_by(
            uuid: document_capture_session_uuid,
          )
          document_capture_session.socure_docv_transaction_token = document_response.dig(
            :data,
            :docvTransactionToken,
          )
          document_capture_session.socure_docv_capture_app_url = document_response.dig(
            :data,
            :url,
          )
          document_capture_session.save
          # useful for analytics
          @msg = document_response[:msg]
          @reference_id = document_response[:referenceId]
        end

        def update
          result = handle_stored_result(
            user: document_capture_session.user,
            store_in_session: false,
          )

          if result.success?
            redirect_to idv_hybrid_mobile_capture_complete_url
          else
            redirect_to idv_hybrid_mobile_socure_document_capture_url
          end
        end
      end
    end
  end
end
