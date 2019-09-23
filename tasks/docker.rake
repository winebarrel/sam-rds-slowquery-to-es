# frozen_string_literal: true

namespace :docker do
  namespace :'lambda-ruby-bundle' do
    task :build do
      cd 'lambda-ruby-bundle' do
        sh 'docker', 'build', '-t', 'lambda-ruby-bundle:ruby2.5', '.'
      end
    end
  end
end
