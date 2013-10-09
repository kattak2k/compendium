require 'compendium/result_set'
require 'compendium/params'

module Compendium
  class Query
    attr_reader :name, :results, :metrics
    attr_accessor :options, :proc, :through

    def initialize(name, options, proc)
      @name = name
      @options = options
      @proc = proc
      @metrics = MetricSet.new
    end

    def run(params, context = self)
      collect_results(params, context)
      collect_metrics(context)

      @results
    end

    def add_metric(name, proc, options = {})
      Compendium::Metric.new(name, self.name, proc, options).tap { |m| @metrics << m }
    end

    def render_table(template, &block)
      Compendium::Presenters::Table.new(template, self, &block).render
    end

    def render_chart(template, &block)
      Compendium::Presenters::Chart.new(template, self, &block).render
    end

    def ran?
      !@results.nil?
    end

    def nil?
      proc.nil?
    end

    def chart?
      true
    end

    def table?
      true
    end

  private

    def collect_results(params, context)
      if through.nil?
        args = params
      else
        through.run(params, context) unless through.ran?
        args = through.results.records
      end

      command = context.instance_exec(args, &proc) if proc
      command = fetch_results(command)
      @results = ResultSet.new(command) if command
    end

    def collect_metrics(context)
      metrics.each{ |m| m.run(context, results) }
    end

    def fetch_results(command)
      if options.key?(:through) or options.fetch(:collect, nil) == :active_record
        command
      else
        ::ActiveRecord::Base.connection.select_all(command.respond_to?(:to_sql) ? command.to_sql : command)
      end
    end
  end
end