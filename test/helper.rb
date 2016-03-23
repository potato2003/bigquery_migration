#!/usr/bin/env ruby

require 'test/unit'
require 'rr'
require 'test/unit/power_assert'
require 'pry'
require 'bigquery_schema_migration'

APP_ROOT = File.dirname(__dir__)
TEST_ROOT = File.join(APP_ROOT, 'test')
JSON_KEYFILE = File.join(APP_ROOT, "your-project-000.json")

BigquerySchemaMigration.logger = Logger.new(nil)
