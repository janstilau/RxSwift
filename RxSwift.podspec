
Pod::Spec.new do |s|
  s.name             = "RxSwift"
  s.version          = "6.5.0"
  s.summary          = "RxSwift is a Swift implementation of Reactive Extensions"
  s.description      = <<-DESC
描述描述描述
描述描述描述
                        DESC
  s.homepage         = "https://github.com/ReactiveX/RxSwift"
  s.license          = 'MIT'
  s.author           = { "Krunoslav Zaher" => "krunoslav.zaher@gmail.com" }
  s.source           = { :git => "https://github.com/ReactiveX/RxSwift.git", :tag => s.version.to_s }

  s.requires_arc          = true

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'
  s.watchos.deployment_target = '3.0'
  s.tvos.deployment_target = '9.0'

  s.source_files          = 'RxSwift/**/*.swift', 'Platform/**/*.swift'
  # 这里面都是软连接文件.
  s.exclude_files         = 'RxSwift/Platform/**/*.swift'

  s.swift_version = '5.1'
end
