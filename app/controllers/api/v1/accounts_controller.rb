# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create, :update ]
  before_action :set_account, only: [ :show, :update ]

  def index
    family = current_resource_owner.family
    accounts_query = family.accounts.visible.alphabetically

    @pagy, @accounts = pagy(
      accounts_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    render :index
  rescue => e
    Rails.logger.error "AccountsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "AccountsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family

    unless Accountable::TYPES.include?(account_params[:accountable_type])
      render json: {
        error: "validation_failed",
        message: "Invalid account type. Must be one of: #{Accountable::TYPES.join(', ')}"
      }, status: :unprocessable_entity
      return
    end

    opening_balance_date = begin
      account_params[:opening_balance_date].presence&.to_date
    rescue Date::Error
      nil
    end || (Time.zone.today - 2.years)

    attrs = {
      name: account_params[:name],
      balance: account_params[:balance] || 0,
      currency: account_params[:currency] || family.currency,
      accountable_type: account_params[:accountable_type],
      accountable_attributes: {}
    }
    attrs[:institution_name] = account_params[:institution_name] if account_params[:institution_name].present?
    attrs[:notes] = account_params[:notes] if account_params[:notes].present?

    @account = family.accounts.create_and_sync(attrs, opening_balance_date: opening_balance_date)
    @account.lock_saved_attributes!

    render :show, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Account could not be created",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "AccountsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def update
    attrs = {}
    attrs[:name]             = account_params[:name]             if params[:account]&.key?(:name)
    attrs[:institution_name] = account_params[:institution_name] if params[:account]&.key?(:institution_name)
    attrs[:notes]            = account_params[:notes]            if params[:account]&.key?(:notes)

    # Handle balance update separately (uses set_current_balance)
    if params[:account]&.key?(:balance)
      new_balance = account_params[:balance].to_d
      if new_balance != @account.balance
        result = @account.set_current_balance(new_balance)
        unless result.success?
          render json: {
            error: "validation_failed",
            message: result.error_message
          }, status: :unprocessable_entity
          return
        end
      end
    end

    if attrs.any? && !@account.update(attrs)
      render json: {
        error: "validation_failed",
        message: "Account could not be updated",
        errors: @account.errors.full_messages
      }, status: :unprocessable_entity
      return
    end

    @account.lock_saved_attributes!
    @account.reload
    render :show
  rescue => e
    Rails.logger.error "AccountsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def set_account
      family = current_resource_owner.family
      @account = family.accounts.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Account not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def account_params
      params.require(:account).permit(
        :name, :balance, :currency, :accountable_type,
        :institution_name, :notes, :opening_balance_date
      )
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
