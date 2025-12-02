Rails.application.routes.draw do
  get "pages/index"
  get "guides/ruby_overview"
  get "guides/ruby_controller"
  get "guides/ruby_view"
  get "guides/ruby_rich_view"
  get "guides/ruby_model"


  root to: redirect('/pages/index')
  # get 'pages/index', to: 'pages#index'

  get "rails_doc/routing"
  get "rails_doc/migration"
  get "rails_doc/active_record"
  get "mvc/index"
  get "mvc/controller"
  get "mvc/model"
  get "mvc/view"
  

  get 'my/page1'
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
