require 'active_record'

require 'active_support/core_ext/hash'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/inflections'
require 'active_support/configurable'
require 'active_support/concern'

require 'i18n'

require 'synchronizable/version'
require 'synchronizable/models/import'
require 'synchronizable/synchronizer'
require 'synchronizable/model'

locale_paths = File.join(File.dirname(__FILE__),
  'synchronizable', 'locale', '*.yml')

Dir[locale_paths].each { |path| I18n.load_path << path }
I18n.backend.load_translations unless defined?(Rails)

I18n.config.enforce_available_locales = true
I18n.default_locale = :en
I18n.available_locales = [:en, :ru]

module Synchronizable
  include ActiveSupport::Configurable

  config_accessor :models do
    {}
  end
  config_accessor :logging do
    {
      :verbose  => true,
      :colorize => true
    }
  end

  # Syncs models that is defined in {Synchronizable#models}
  #
  # @param models [Array] array of models that should be synchronized.
  #   This take a precedence over models defined in {Synchronizable#models}.
  #   If not specified and {Synchronizable#models} is empty, than it will try
  #   to synchronize only those models which have a corresponding synchronizers.
  #
  # @return [Synchronizable::Context] synchronization context
  #
  # @see Synchronizable::Context
  def self.sync(*models)
    source = source_models(models)
    source.each { |model| model.try(:safe_constantize).try(:sync) }
  end

  private

  def self.source_models(models)
    source = models.present? ? models : self.models
    source = source.present? ? source : lookup_models
  end

  def self.lookup_models
    ActiveRecord::Base.descendants.select do |model|
      model.included_modules.include?(Synchronizable::Model)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include Synchronizable::Model
end
