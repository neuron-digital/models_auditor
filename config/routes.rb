ModelsAuditor::Engine.routes.draw do
  get '(/index)(/page/:page)', to: 'audit#index', as: :models_auditor_requests, page: /\d+/, format: [:json, :html]

  root to: 'audit#index'
end
