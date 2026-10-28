defmodule Marshall.Repo.Migrations.ThreadSubscriptionRevoked do
  @moduledoc """
  Allows thread subscriptions to record revocation after lost read authority.
  """

  use Ecto.Migration

  def up do
    drop_if_exists constraint(:agent_thread_tool_subscriptions, :thread_subscription_state)

    create constraint(:agent_thread_tool_subscriptions, :thread_subscription_state,
             check: """
               state IN ('active', 'inactive', 'revoked')
             """
           )
  end

  def down do
    execute(
      "UPDATE agent_thread_tool_subscriptions SET state = 'inactive' WHERE state = 'revoked'"
    )

    drop_if_exists constraint(:agent_thread_tool_subscriptions, :thread_subscription_state)

    create constraint(:agent_thread_tool_subscriptions, :thread_subscription_state,
             check: """
               state IN ('active', 'inactive')
             """
           )
  end
end
