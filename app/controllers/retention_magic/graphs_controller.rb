require_dependency "retention_magic/application_controller"

module RetentionMagic
  class GraphsController < ApplicationController
    def index
      # RetentionMagic configuration setup
      @user_class = RetentionMagic.user_class.constantize

      @first_user = @user_class.order(:created_at).first
      first_cohort_month = 12.months.ago.to_date.beginning_of_month
      today = Date.today

      difference_in_days_between_now_and_first_cohort = (today.beginning_of_month - first_cohort_month).to_i

      # For presenting the widgets
      @current_cohort_label = today.strftime("%U/%Y")
      @number_of_months = difference_in_days_between_now_and_first_cohort / 30

      @graphs = {
        activation: {
          signup_without_activation: {},
          one_activation: {},
          five_activations: {},
        },
        retention: {}
      }

      retention_models = RetentionMagic.retention_models.map { |class_name| class_name.constantize }
      activation_fields_for_query = RetentionMagic.activation_counter_columns.join(" + ")

      0.upto(@number_of_months) do |month|
        cohort_start = first_cohort_month + month.months
        cohort_start_end = (cohort_start + 1.month).beginning_of_month

        cohort_users = @user_class.where(created_at: cohort_start..cohort_start_end)
        number_of_cohort_users = cohort_users.count

        if number_of_cohort_users == 0
          signups_without_activation = 0
          one_activation = 0
          five_activations = 0
        else
          signups_without_activation = cohort_users.where("#{activation_fields_for_query} = 0").count
          one_activation = cohort_users.where("#{activation_fields_for_query} >= 1 AND #{activation_fields_for_query} < 5").count
          five_activations = cohort_users.where("#{activation_fields_for_query} >= 5").count
        end

        if number_of_cohort_users > 0
          @graphs[:activation][:one_activation][cohort_start] = (one_activation.to_f / number_of_cohort_users.to_f) * 100.0
          @graphs[:activation][:five_activations][cohort_start] = (five_activations.to_f / number_of_cohort_users.to_f) * 100.0
          @graphs[:activation][:signup_without_activation][cohort_start] = (signups_without_activation.to_f / number_of_cohort_users.to_f) * 100.0
        else
          @graphs[:activation][:one_activation][cohort_start] = 0
          @graphs[:activation][:five_activations][cohort_start] = 0
          @graphs[:activation][:signup_without_activation][cohort_start] = 0
        end


        cohort_start_label = cohort_start.strftime("w%U %Y")
        @graphs[:retention][cohort_start_label] = {}
        cohort_user_ids = cohort_users.pluck(:id)
        cohort_size = cohort_users.count

        difference_in_days_between_now_and_cohort_start = (today.beginning_of_month - cohort_start.to_date).to_i
        number_of_months_in_this_cohort = difference_in_days_between_now_and_cohort_start / 30

        0.upto(number_of_months_in_this_cohort) do |month|
          retention_month = (cohort_start + month.months).beginning_of_month
          if month == 0
            @graphs[:retention][cohort_start_label][retention_month] = cohort_size
          else
            retention_month_end = (retention_month + 1.month).beginning_of_month

            records_per_user = {}

            retention_models.each do |model|
              count_per_user = model.where(user_id: cohort_user_ids).where(created_at: retention_month..retention_month_end).group("user_id").count
              count_per_user.each do |uid, count|
                records_per_user[uid] ||= 0
                records_per_user[uid] += count
              end
            end

            if cohort_user_ids.empty?
              @graphs[:retention][cohort_start_label][retention_month] = 0
            else
              @graphs[:retention][cohort_start_label][retention_month] = records_per_user.keys.size
            end
          end
        end
      end

    end
  end
end
