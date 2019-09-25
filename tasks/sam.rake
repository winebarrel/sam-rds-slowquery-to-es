# frozen_string_literal: true

require 'base64'
require 'json'
require 'stringio'
require 'tempfile'
require 'yaml'
require 'zlib'

def sam_build_logs_event
  message = {
    messageType: 'DATA_MESSAGE',
    owner: '822997939312',
    logGroup: '/aws/rds/cluster/my-cluster/slowquery',
    logStream: 'my-instance',
    subscriptionFilters: [
      'LambdaStream_rds-slowquery-to-es'
    ],
    logEvents: [
      {
        id: '34988627466400403128808512274575692581164466220493963264',
        timestamp: 1_568_944_318_000,
        message: format(<<~SQL, time: Time.now.utc.strftime('%y%m%d %_H:%M:%S'))
          # Time: %<time>s
          # User@Host: root[root] @  [10.0.1.133]  Id:  1139
          # Query_time: 10.955901  Lock_time: 0.000120 Rows_sent: 1  Rows_examined: 11376188
          SET timestamp=1568944318;
          select sql_no_cache count(1) from (select * from salaries order by rand()) t1;
        SQL
      }
    ]
  }

  gzip = StringIO.new.yield_self do |buf|
    Zlib::GzipWriter.wrap(buf) do |gz|
      gz.write(message.to_json)
    end

    buf.string
  end

  {
    awslogs: {
      data: Base64.strict_encode64(gzip)
    }
  }.to_json
end

def sam_with_event_file
  Tempfile.create('sam_logs_event') do |f|
    f.puts(sam_build_logs_event)
    f.flush
    yield(f)
  end
end

def sam_git_hash
  `git rev-parse HEAD`.strip
end

namespace :sam do
  namespace :local do
    task :invoke do
      sam_with_event_file do |event|
        sh 'sam', 'local', 'invoke', 'RdsSlowqueryToEsFunction',
           '--event', event.path,
           '-n', 'local-env.json',
           '--docker-network', 'sam-rds-rds-slowquery-to-es'
      end
    end
  end

  task :bundle do
    cd 'rds_slowquery_to_es' do
      unless File.exist?('pt-fingerprint')
        raise '"pt-fingerprint" not found. You must be run "bundle exec rake pt-fingerprint:download"'
      end

      sh 'docker', 'run',
         '-v', "#{pwd}:/mnt",
         '-w', '/mnt',
         'lambda-ruby-bundle:ruby2.5',
         'bash', '-c', 'bundle install --path vendor/bundle && bundle clean'
    end
  end

  task package: :bundle do
    sh 'sam', 'package',
       '--template-file', 'template.yaml',
       '--output-template-file', 'packaged.yaml',
       '--s3-bucket', ENV.fetch('S3_BUCKET'),
       '--s3-prefix', 'sam-rds-slowquery-to-es'
  end

  task 'deploy-noop': :package do
    out = `
      sam deploy \
        --template-file packaged.yaml \
        --stack-name sam-rds-slowquery-to-es \
        --no-execute-changeset \
        --parameter-overrides Revision=#{sam_git_hash}
     `

    cmd = out.each_line.find { |l| l =~ /aws cloudformation describe-change-set/ }

    if cmd
      sh cmd
      sh cmd.sub('describe-change-set', 'delete-change-set')
    end
  end

  task deploy: :package do
    sh 'sam', 'deploy',
       '--template-file', 'packaged.yaml',
       '--stack-name', 'sam-rds-slowquery-to-es',
       '--no-fail-on-empty-changeset',
       '--parameter-overrides', "Revision=#{sam_git_hash}"
  end

  task :invoke do
    sam_with_event_file do |event|
      sh 'aws', 'lambda', 'invoke',
         '--function-name', 'sam-rds-slowquery-to-es',
         '--payload', "file://#{event.path}",
         '/dev/stdout'
    end

    elasticsearch_url = YAML.load_file('template.yaml')
                            .fetch('Resources')
                            .fetch('RdsSlowqueryToEsFunction')
                            .fetch('Properties')
                            .fetch('Environment')
                            .fetch('Variables')
                            .fetch('ELASTICSEARCH_URL')

    puts "see #{elasticsearch_url}/_plugin/kibana"
  end
end
