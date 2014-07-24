require 'colorize'

require 'synchronisable/error_handler'
require 'synchronisable/context'
require 'synchronisable/input_parser'
require 'synchronisable/source'
require 'synchronisable/models/import'
require 'synchronisable/helper/logging'
require 'synchronisable/worker/record'
require 'synchronisable/worker/associations'

module Synchronisable
  # Responsible for model synchronization.
  #
  # @api private
  class Controller
    include Helper::Logging

    attr_reader :logger

    class << self
      # Creates a new instance of controller and initiates model synchronization.
      #
      # @overload call(model, data, options)
      #   @param model [Class] model class to be synchronized
      #   @param options [Hash] synchronization options
      #   @option options [Hash] :include assocations to be synchronized.
      #     Use this option to override `has_one` & `has_many` assocations
      #     defined in model synchronizer.
      # @overload call(model, data)
      # @overload call(model)
      #
      # @return [Synchronisable::Context] synchronization context
      def call(model, *args)
        options = args.extract_options!
        data = args.first

        new(model, options).call(data)
      end
    end

    # Initiates model synchronization.
    #
    # @param data [Array<Hash>, Array<String>, Array<Integer>, String, Integer]
    #   synchronization data.
    #   If not specified, it will try to get array of hashes to sync with
    #   using defined gateway class or `fetch` lambda/proc
    #   defined in corresponding synchronizer
    #
    # @return [Synchronisable::Context] synchronization context
    #
    # @see Synchronisable::InputParser
    def call(data)
      sync do |context|
        error_handler = ErrorHandler.new(logger, context)
        context.before = @model.imports_count

        hashes = @input.parse(data)
        hashes.each do |attrs|
          source = Source.new(@model, @parent, @includes, attrs)

          error_handler.handle(source) do
            source.prepare

            record_worker = Worker::Record.new(@synchronizer, source)
            associations_worker = Worker::Associations.new(@synchronizer, source)

            @synchronizer.with_sync_callbacks(source) do
              associations_worker.sync_parent_associations
              record_worker.sync_record
              associations_worker.sync_child_associations
            end
          end
        end

        context.after = @model.imports_count
        context.deleted = 0
      end
    end

    private

    def initialize(model, options)
      @model, @synchronizer = model, model.synchronizer
      @logger = @synchronizer.logger

      @includes = options[:includes]
      @parent = options[:parent]

      @input = InputParser.new(@model, @synchronizer)
    end

    def sync
      @logger.progname = "#{@model} synchronization"
      log_info('STARTING', :yellow, true)

      context = Context.new(@model, @parent.try(:model))
      yield context

      log_info('DONE', :yellow, true)
      log_info(context.summary_message, :cyan, true)

      context
    end
  end
end
