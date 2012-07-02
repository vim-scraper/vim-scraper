source 'http://rubygems.org'

gem 'bzip2-ruby'  ,'~> 0.2.6'
gem 'erubis'      ,'~> 2.6.6'
gem 'feedzirra'   ,'~> 0.0.24'
gem 'hashie'      ,'~> 1.2'
gem 'htmlentities','~> 4.2.1'
gem 'i18n'        ,'~> 0.4.1'
gem 'json'        ,'~> 1.4.6'
gem 'mail'        ,'~> 2.2.7'
gem 'mime-types'  ,'~> 1.16'
gem 'octokit'     ,'1.8.1'


# the following gems are, ah, special...

# the pdf magic in mimemagic 0.1.8 is far too loose (recognizes textfiles and zipfiles as pdf)
# github issue: https://github.com/minad/mimemagic/issues/4   Looks like we're on 0.1.7 permanently.
gem 'mimemagic', '= 0.1.7'

# scraper problems with 0.8.3, mad monkeypatching for 0.8.2.  Only viable fix is to convert to Nokogiri.
gem 'hpricot', '= 0.8.2'

# we use some convenience features that other retryables don't support (yet?)
gem 'retryable', :git => 'git://github.com/bronson/retryable.git'

# Desperately need bugfix for https://github.com/minad/gitrb/pull/11 but it looks like gitrb is end-of-lifed.
gem 'gitrb', :git => 'git://github.com/bronson/gitrb.git', :branch => 'patch-1'



group :development do
  gem 'guard-rspec'
end

group :test do
  gem 'rake'                # needed by travis-ci
  gem 'rspec', '~> 2.5'
  gem 'webmock', '~> 1.8'   # to mock github requests
end

