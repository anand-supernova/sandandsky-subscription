Spree::Order.class_eval do

  has_one :order_subscription, class_name: "Spree::OrderSubscription", dependent: :destroy
  has_one :parent_subscription, through: :order_subscription, source: :subscription
  has_many :subscriptions, class_name: "Spree::Subscription",
                           foreign_key: :parent_order_id,
                           dependent: :restrict_with_error

  self.state_machine.after_transition to: :complete, do: :enable_subscriptions, if: :any_disabled_subscription?

  after_update :update_subscriptions

  def subscriptions_match(line_item, other_line_item_or_voucher_attributes)
   if other_line_item_or_voucher_attributes['subscribe'] == true && line_item.subscription?
     if line_item.subscription.subscription_frequency_id != other_line_item_or_voucher_attributes[:subscription_frequency_id]
       line_item.subscription_frequency_id = other_line_item_or_voucher_attributes[:subscription_frequency_id]
     end
   end
   return true
  end

  private

    def enable_subscriptions
      subscriptions.each do |subscription|
        subscription.update(
          source: payments.from_credit_card.first.source,
          enabled: true,
          ship_address: ship_address.clone,
          bill_address: bill_address.clone
        )
      end
    end

    def any_disabled_subscription?
      subscriptions.disabled.any?
    end

    def update_subscriptions
      line_items.each do |line_item|
        if line_item.subscription_attributes_present?
          subscriptions.find_by(variant: line_item.variant).update(line_item.updatable_subscription_attributes)
        end
      end
    end

end
