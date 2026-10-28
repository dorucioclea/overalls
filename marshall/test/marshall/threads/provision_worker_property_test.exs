defmodule Marshall.Threads.ProvisionWorkerPropertyTest do
  use ExUnit.Case, async: true
  import Hegel
  import Hegel.Gen

  @retryable [:machine_not_ready, :agent_unavailable]
  @terminal [
    :machine_unavailable,
    :forbidden,
    :provider_failed,
    :capability_denied,
    :access_revoked,
    :invalid_request,
    :not_found
  ]

  property "only transient activation failures are retried", test_cases: 100 do
    reason = draw("reason", member_of(@retryable ++ @terminal))
    noise = draw("noise", term())

    assert Marshall.Threads.ProvisionWorker.retryable_activation_reason?(reason) ==
             reason in @retryable

    refute Marshall.Threads.ProvisionWorker.retryable_activation_reason?({reason, noise})
  end
end
