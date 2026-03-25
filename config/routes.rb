Rails.application.routes.draw do
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
      end
      resources :favorites, only: [ :index ]
      resources :schedules, except: [ :new, :edit ]
      resources :reviews, only: [ :update, :destroy ]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
