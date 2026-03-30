Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  get "p/:share_token", to: "profiles#show", as: :public_profile

  namespace :api do
    namespace :v1 do
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      post "auth/forgot_password", to: "auth#forgot_password"
      post "auth/otp_confirmation", to: "auth#otp_confirmation"
      post "auth/verify_reset_token", to: "auth#verify_reset_token"
      patch "auth/reset_password", to: "auth#reset_password"

      resources :accounts do
        patch :change_password, on: :member
        patch :toggle_business, on: :collection
        patch :submit_verification, on: :collection
      end

      resources :categories, only: [ :index, :show ]
      resources :business_profiles, except: [ :new, :edit ] do
        get :qr_code, on: :member
        post :favorite, on: :member
        delete :unfavorite, on: :member
        resources :reviews, only: [ :index, :create ]
        resource :chat_request, only: [ :create ], controller: :chat_requests
      end
      resources :chat_conversations, only: [ :index, :show, :create ] do
        resources :chat_messages, only: [ :index, :create ] do
          collection do
            post :mark_read
          end
        end
        resources :chat_sessions, only: [ :index ] do
          post :accept, on: :member
          post :decline, on: :member
          post :end_session, on: :member
          post :heartbeat, on: :member
        end
      end
      resources :wallet_transactions, only: [ :index ]
      resources :notifications, only: [ :index ] do
        collection do
          get :unread_count
          patch :mark_all_read
        end
        member do
          patch :mark_read
        end
      end
      resources :device_installations, only: [ :create, :destroy ]
      resources :favorites, only: [ :index ]
      resources :schedules, except: [ :new, :edit ]
      resources :reviews, only: [ :update, :destroy ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
