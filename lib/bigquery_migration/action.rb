require_relative 'schema'
require_relative 'error'
require_relative 'hash_util'
require_relative 'bigquery_wrapper'

class BigqueryMigration
  class Action
    attr_reader :config, :opts

    def initialize(config, opts = {})
      @config = HashUtil.deep_symbolize_keys(config)
      @opts = HashUtil.deep_symbolize_keys(opts)

      @action = @config[:action]
      unless self.class.supported_actions.include?(@action)
        raise ConfigError, "Action #{@action} is not supported"
      end
    end

    def run
      begin
        success = true
        result = send(@action)
      rescue => e
        result = { error: e.message, error_class: e.class.to_s, error_backtrace: e.backtrace }
        success = false
      ensure
        success = false if result[:success] == false
      end
      [success, result]
    end

    def self.supported_actions
      Set.new(%w[
        create_dataset
        create_table
        delete_table
        patch_table
        migrate_table
        insert
        preview
        insert_select
        copy_table
        table_info
        migrate_partitioned_table
      ])
    end

    def client
      @client ||= BigqueryMigration.new(@config, @opts)
    end

    def create_dataset
      client.create_dataset
    end

    def create_table
      client.create_table(columns: config[:columns])
    end

    def delete_table
      client.delete_table
    end

    def patch_table
      client.patch_table(
        columns: config[:columns],
        add_columns: config[:add_columns]
      )
    end

    def migrate_table
      client.migrate_table(
        schema_file: config[:schema_file],
        columns: config[:columns],
        backup_dataset: config[:backup_dataset],
        backup_table: config[:backup_table]
      )
    end

    def migrate_partitioned_table
      client.migrate_partitioned_table(
        schema_file: config[:schema_file],
        columns: config[:columns],
      )
    end

    def insert
      client.insert_all_table_data(rows: config[:rows])
    end

    def preview
      client.list_table_data(max_results: config[:max_results])
    end

    def copy_table
      client.copy_table(
        destination_table: config[:destination_table],
        destination_dataset: config[:destination_dataset],
        source_table: config[:source_table],
        source_dataset: config[:source_dataset],
        write_disposition: config[:write_disposition],
      )
    end

    def insert_select
      client.insert_select(
        query: config[:query],
        destination_table: config[:destination_table],
        destination_dataset: config[:destination_dataset],
        write_disposition: config[:write_disposition],
      )
    end

    def table_info
      if config[:prefix]
        tables = client.list_tables[:tables].select {|table| table.start_with?(config[:prefix]) }
        table_infos = tables.map do |table|
          result = client.get_table(table: table)
          result.delete(:responses)
          result
        end
        result = {
          sum_num_bytes: table_infos.map {|info| info[:num_bytes].to_i }.inject(:+),
          sum_num_rows: table_infos.map {|info| info[:num_rows].to_i }.inject(:+),
          table_infos: table_infos,
        }
      else
        client.get_table
      end
    end
  end
end
