Pod::Spec.new do |s|
  s.name             = 'pdf_viewer'
  s.version          = '0.1.0'
  s.summary          = 'Native PDF rendering, text layer and selection for Flutter.'
  s.description      = <<-DESC
Renders PDF pages with PDFKit and exposes per-character text boxes to Dart through FFI.
                       DESC
  s.homepage         = 'https://github.com/SunnatilloShavkatov/pdf_viewer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sunnatillo Shavkatov' => 'sunnatilloshavkatov@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'pdf_viewer/Sources/pdf_viewer/**/*.swift',
                       'pdf_viewer/Sources/pdf_viewer_c/*.{h,m}'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'PDFKit', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
