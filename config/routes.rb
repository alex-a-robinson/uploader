Rails.application.routes.draw do
  root 'uploads#index'

  resources :uploads, :path => '/', param: :identifier, :identifier => /.*/
end
