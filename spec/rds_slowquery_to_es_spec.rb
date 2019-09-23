# frozen_string_literal: true

RSpec.describe '#lambda_handler' do
  let(:time) do
    Time.parse('2019/01/23 12:34:56 UTC')
  end

  let(:log_time_format) do
    '%y%m%d %_H:%M:%S'
  end

  let(:sql) do
    format(<<~SQL, time: time.strftime(log_time_format))
      # Time: %<time>s
      # User@Host: root[root] @  [10.0.1.133]  Id:  1139
      # Query_time: 10.955901  Lock_time: 0.000120 Rows_sent: 1  Rows_examined: 11376188
      SET timestamp=1568944318;
      select sql_no_cache count(1) from (select * from salaries order by rand()) t1;
    SQL
  end

  let(:log_group) do
    '/aws/rds/cluster/my-cluster/slowquery'
  end

  let(:log_stream) do
    'my-instance'
  end

  let(:message) do
    {
      messageType: 'DATA_MESSAGE',
      owner: '822997939312',
      logGroup: log_group,
      logStream: log_stream,
      subscriptionFilters: [
        'LambdaStream_slowquery-to-es'
      ],
      logEvents: [
        {
          id: '34988627466400403128808512274575692581164466220493963264',
          timestamp: 1_568_944_318_000,
          message: sql
        }
      ]
    }
  end

  let(:event) do
    gzip = StringIO.new.yield_self do |buf|
      Zlib::GzipWriter.wrap(buf) do |gz|
        gz.write(message.to_json)
      end

      buf.string
    end

    {
      'awslogs' => {
        'data' => Base64.strict_encode64(gzip)
      }
    }
  end

  let(:elasticsearch_client) do
    Elasticsearch::Client.new
  end

  before do
    Timecop.freeze(time)
    allow(LOGGER).to receive(:info)
    allow(self).to receive(:build_elasticsearch_client).and_return(elasticsearch_client)
  end

  after do
    Timecop.return
  end

  context 'when receive a slowquery' do
    specify 'post to elasticsearch' do
      expect(elasticsearch_client).to receive(:bulk).with(
        body: [
          {
            index: {
              _index: 'aws_rds_cluster_my-cluster_slowquery-2019.01.23',
              data: {
                'time' => '190123 12:34:56',
                'user@host' => 'root[root] @  [10.0.1.133]',
                'id' => '1139',
                'query_time' => 10.955901,
                'lock_time' => 0.00012,
                'rows_sent' => 1,
                'rows_examined' => 11_376_188,
                'timestamp' => '2019-01-23T12:34:56+00:00',
                'user' => 'root[root]',
                'host' => '[10.0.1.133]',
                'sql_fingerprint' => 'select sql_no_cache count(?) from (select * from salaries order by rand()) t?',
                'sql_hash' => '17d542f685776bcefbfd62c9b94f4d4694b49479',
                'log_group' => '/aws/rds/cluster/my-cluster/slowquery',
                'log_stream' => 'my-instance',
                'log_timestamp' => 1_568_944_318_000,
                'sql' => <<~SQL
                  SET timestamp=1568944318;
                  select sql_no_cache count(1) from (select * from salaries order by rand()) t1;
                SQL
              }
            }
          }
        ]
      ).and_return({})

      retval = lambda_handler(event: event, context: nil)
      expect(retval).to be_nil
    end
  end

  context 'when receive a slowquery with timezone' do
    let(:time) do
      Time.parse('2019/01/23 12:34:56 PDT')
    end

    let(:log_time_format) do
      '%Y-%m-%dT%H:%M:%S.%6N%:z'
    end

    specify 'post to elasticsearch' do
      expect(elasticsearch_client).to receive(:bulk).with(
        body: [
          {
            index: {
              _index: 'aws_rds_cluster_my-cluster_slowquery-2019.01.23',
              data: {
                'time' => '2019-01-23T12:34:56.000000-07:00',
                'user@host' => 'root[root] @  [10.0.1.133]',
                'id' => '1139',
                'query_time' => 10.955901,
                'lock_time' => 0.00012,
                'rows_sent' => 1,
                'rows_examined' => 11_376_188,
                'timestamp' => '2019-01-23T12:34:56-07:00',
                'user' => 'root[root]',
                'host' => '[10.0.1.133]',
                'sql_fingerprint' => 'select sql_no_cache count(?) from (select * from salaries order by rand()) t?',
                'sql_hash' => '17d542f685776bcefbfd62c9b94f4d4694b49479',
                'log_group' => '/aws/rds/cluster/my-cluster/slowquery',
                'log_stream' => 'my-instance',
                'log_timestamp' => 1_568_944_318_000,
                'sql' => <<~SQL
                  SET timestamp=1568944318;
                  select sql_no_cache count(1) from (select * from salaries order by rand()) t1;
                SQL
              }
            }
          }
        ]
      ).and_return({})

      retval = lambda_handler(event: event, context: nil)
      expect(retval).to be_nil
    end
  end

  context 'when receive a instance slowquery' do
    let(:log_group) do
      '/aws/rds/instance/my-instance/slowquery'
    end

    let(:log_stream) do
      'my-instance'
    end

    specify 'post to elasticsearch' do
      expect(elasticsearch_client).to receive(:bulk).with(
        body: [
          {
            index: {
              _index: 'aws_rds_instance_my-instance_slowquery-2019.01.23',
              data: {
                'time' => '190123 12:34:56',
                'user@host' => 'root[root] @  [10.0.1.133]',
                'id' => '1139',
                'query_time' => 10.955901,
                'lock_time' => 0.00012,
                'rows_sent' => 1,
                'rows_examined' => 11_376_188,
                'timestamp' => '2019-01-23T12:34:56+00:00',
                'user' => 'root[root]',
                'host' => '[10.0.1.133]',
                'sql_fingerprint' => 'select sql_no_cache count(?) from (select * from salaries order by rand()) t?',
                'sql_hash' => '17d542f685776bcefbfd62c9b94f4d4694b49479',
                'log_group' => '/aws/rds/instance/my-instance/slowquery',
                'log_stream' => 'my-instance',
                'log_timestamp' => 1_568_944_318_000,
                'sql' => <<~SQL
                  SET timestamp=1568944318;
                  select sql_no_cache count(1) from (select * from salaries order by rand()) t1;
                SQL
              }
            }
          }
        ]
      ).and_return({})

      retval = lambda_handler(event: event, context: nil)
      expect(retval).to be_nil
    end
  end

  context 'when posting fails' do
    specify 'post to elasticsearch' do
      expect(elasticsearch_client).to receive(:bulk).and_return('errors' => true)

      expect do
        lambda_handler(event: event, context: nil)
      end.to raise_error('{"errors"=>true}')
    end
  end
end
