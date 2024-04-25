Pod::Spec.new do |spec|
  spec.name         = 'KeenClientTD'
  spec.version      = '4.1.0'
  spec.license      = { type: 'MIT' }
  spec.platforms    = { ios: '12.0', tvos: '12.0' }
  spec.homepage     = 'https://github.com/treasure-data/KeenClient-iOS'
  spec.authors      = { 'Mitsunori Komatsu' => 'mitsu@treasure-data.com' }
  spec.summary      = 'Keen iOS client library forked by TD.'
  spec.description	= <<-DESC
                      The Keen iOS client is designed to be simple to develop with, yet incredibly flexible.  Our goal is to let you decide what events are important to you, use your own vocabulary to describe them, and decide when you want to send them to Keen service.
                      This is a forked project by TD. The original cool project is https://github.com/keenlabs/KeenClient-iOS.
  DESC
  spec.source       = { git: 'https://github.com/treasure-data/KeenClient-iOS.git', tag: spec.version.to_s }
  spec.source_files = 'KeenClient/*.{h,m}'
  spec.resources    = 'PrivacyInfo.xcprivacy'
  spec.public_header_files = 'KeenClient/*.h'
  spec.requires_arc = true

  spec.subspec 'keen_sqlite' do |ks|
    ks.source_files = 'Library/sqlite-amalgamation/*.{h,c}'
    ks.private_header_files = 'Library/sqlite-amalgamation/*.h'
    ks.compiler_flags = '-w', '-Xanalyzer', '-analyzer-disable-all-checks'
  end
end
