Pod::Spec.new do |s|
  s.name = 'APIClient'
  s.ios.deployment_target = '10.0'
  s.version = '0.1.0'
  s.source = { :git => 'git@github.com:folio-sec/APIClient.git', :tag => 'v0.1.0' }
  s.authors = 'OpenAPI Generator'
  s.license = 'Proprietary'
  s.summary = 'Folio API Client'
  s.source_files = 'APIClient/*.swift'
end
