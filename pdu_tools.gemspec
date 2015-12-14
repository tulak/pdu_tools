Gem::Specification.new do |s|
  s.name        = 'pdu_tools'
  s.version     = '0.0.10'
  s.date        = '2015-12-14'
  s.summary     = "Tools for encoding and decoding GSM SMS PDUs."
  s.description = s.summary
  s.authors     = ["Filip Zachar"]
  s.email       = 'tulak45@gmail.com'
  s.homepage    = 'https://github.com/tulak/pdu_tools'
  s.license     = 'MIT'
  s.files       = Dir["**/*.rb"]

  s.add_runtime_dependency "phone", "~> 1.2.3"
  s.add_runtime_dependency "activesupport", ">= 3.2.0"
end