Rails.application.routes.draw do
  root to: 'clouds#home'  
  
  resource :cloud do
    get 'facebook'
  end
end
