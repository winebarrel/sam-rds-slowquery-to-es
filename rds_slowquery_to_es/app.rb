# frozen_string_literal: true

require 'base64'
require 'digest/sha1'
require 'json'
require 'logger'
require 'open3'
require 'stringio'
require 'time'
require 'zlib'

require 'elasticsearch'

PT_FINGERPRINT_PATH = File.join(__dir__, 'pt-fingerprint')
ELASTICSEARCH_URL = ENV.fetch('ELASTICSEARCH_URL')
LOGGER = Logger.new($stderr)

EXCLUDE_STATEMENTS = Regexp.union(
  /^set timestamp=\?(\n|;\z)/,
  /^use \?\n/
)

EXCLUDE_USERS = [
  'rdsadmin[rdsadmin]'
].freeze

def decode_log(log:)
  data = log.fetch('awslogs').fetch('data')
  data_io = StringIO.new(Base64.decode64(data))
  json_str = Zlib::GzipReader.wrap(data_io, &:read)
  JSON.parse(json_str)
end

def parse_slowquery_header(header_lines:)
  headers = header_lines.flat_map do |line|
    line.split(/([\w@]+): /).slice(1..-1)
  end.map(&:strip)

  headers = Hash[*headers]

  return nil if headers.empty?

  headers.transform_keys!(&:downcase)

  headers['timestamp'] = Time.parse(headers.fetch('time')).iso8601 if headers.key?('time')

  user, host = headers.fetch('user@host').split('@', 2).map(&:strip)
  headers.update('user' => user, 'host' => host)

  %w[query_time lock_time].each { |k| headers[k] = headers.fetch(k).to_f }
  %w[rows_sent rows_examined].each { |k| headers[k] = headers.fetch(k).to_i }

  headers
end

def pt_fingerprint(sql:)
  out, err, status = Open3.capture3(PT_FINGERPRINT_PATH, stdin_data: sql)
  raise "pt-fingerprint failed: stdout=#{out} stderr=#{err}" unless status.success?

  out
end

def parse_slowquery_sql(sql_lines:)
  sql = sql_lines.join
  sql_hash = Digest::SHA1.hexdigest(sql)
  fingerprint = pt_fingerprint(sql: sql)
  fingerprint.gsub!(EXCLUDE_STATEMENTS, '')
  fingerprint.strip!
  fingerprint_hash = Digest::SHA1.hexdigest(fingerprint)

  {
    'sql' => sql, # Note: SQL may contain sensitive information
    'sql_fingerprint' => fingerprint,
    'sql_hash' => sql_hash,
    'sql_fingerprint_hash' => fingerprint_hash
  }
end

def parse_slowquery(log_event:)
  message = log_event.fetch('message')
  header = message.each_line.select { |l| l =~ /\A\s*#/ }

  if header.empty?
    LOGGER.warn("Skip slowquery without header: #{message.inspect.slice(0, 64)}...")
    return nil
  end

  sql = message.each_line.reject { |l| l =~ /\A\s*#/ }
  row = parse_slowquery_header(header_lines: header)
  parsed_sql = parse_slowquery_sql(sql_lines: sql)

  if parsed_sql.fetch('sql_fingerprint', '').strip.empty?
    LOGGER.warn("Skip slowquery without query: #{message.inspect.slice(0, 64)}...")
    return nil
  end

  row.merge(parsed_sql)
end

def build_elasticsearch_client
  Elasticsearch::Client.new(url: ELASTICSEARCH_URL)
end

def post_to_elasticsearch(client:, docs:, index_prefix:)
  index_name = format("#{index_prefix}-%<today>s", today: Time.now.strftime('%Y.%m.%d'))

  body = docs.map do |doc|
    { index: { _index: index_name, data: doc } }
  end

  res = client.bulk(body: body)
  raise res.inspect if res['errors'] == true

  res
end

def filter_row_for_logging(row)
  row.reject { |k, _| k == 'sql_fingerprint' }
end

def lambda_handler(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
  LOGGER.info("Receive a event: #{event.to_s.slice(0, 64)}...")

  log = decode_log(log: event)

  log_group = log.fetch('logGroup')
  log_stream = log.fetch('logStream')
  log_events = log.fetch('logEvents')
  identifier = log_group.split('/').fetch(4)

  LOGGER.info('Parse slowqueries')

  rows = []

  log_events.each do |log_event|
    timestamp = log_event.fetch('timestamp')
    row = parse_slowquery(log_event: log_event)

    next unless row

    if EXCLUDE_USERS.include?(row.fetch('user'))
      LOGGER.warn("Skip because a user to be exclude is included: #{filter_row_for_logging(row)}")
      next
    end

    # NOTE: slowquery log may not include "# Time:"
    row['timestamp'] = Time.at(timestamp / 1000).iso8601 unless row.key?('timestamp')

    rows << row.merge(
      'identifier' => identifier,
      'log_group' => log_group,
      'log_stream' => log_stream,
      'log_timestamp' => timestamp
    )
  end

  es = build_elasticsearch_client
  index_prefix = log_group.sub(%r{\A/}, '').tr('/', '_')

  unless rows.empty?
    LOGGER.info("Post slowqueries: #{rows.map { |r| filter_row_for_logging(r) }}")
    res = post_to_elasticsearch(client: es, docs: rows, index_prefix: index_prefix)
    LOGGER.info("Posted slowqueries to Elasticsearch: #{res}")
  end

  nil
end
