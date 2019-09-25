# frozen_string_literal: true

namespace :'pt-fingerprint' do
  task :download do
    cd 'rds_slowquery_to_es' do
      sh 'curl', '-sSfLO', 'percona.com/get/pt-fingerprint'
      sh 'patch -p 0 -d  .  < ../pt-fingerprint.patch'
      sh 'chmod', '+x', 'pt-fingerprint'
    end
  end
end
