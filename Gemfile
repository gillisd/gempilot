source "https://rubygems.org"

gemspec

gem "benchmark"
gem "irb", "~> 1.15"
gem "minitest"
gem "minitest-reporters"
gem "observer"
gem "rake", require: false
gem "rdoc"
gem "rspec"
gem "rubocop"
gem "rubocop-claude"
gem "rubocop-minitest"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec", "~> 3.9"
gem "zeitwerk"

# rbs, repl_type_completor, and debug ship native extensions that fail to
# build on JRuby; scope them to MRI so `bundle install` works there too.
platforms :mri do
  gem "debug", "~> 1.10"
  gem "rbs"
  gem "repl_type_completor"
end
