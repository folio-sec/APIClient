Pod::Spec.new do |s|
  s.name = 'APIClient'
  s.ios.deployment_target = '10.0'
  s.version = '0.1.0'
  s.source = { git: 'https://github.com/folio-sec/APIClient.git', branch: 'master' }
  s.authors = 'Kishikawa Katsumi'
  s.license = 'Proprietary'
  s.homepage = 'https://github.com/folio-sec/APIClient'
  s.summary = 'Folio API Client'
  s.source_files = 'APIClient/*.swift'
end
