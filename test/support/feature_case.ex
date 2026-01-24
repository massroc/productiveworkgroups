defmodule ProductiveWorkgroupsWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by browser-based feature tests.

  Uses Wallaby for browser automation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      alias ProductiveWorkgroups.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      alias ProductiveWorkgroupsWeb.Router.Helpers, as: Routes

      @endpoint ProductiveWorkgroupsWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ProductiveWorkgroups.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(ProductiveWorkgroups.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    {:ok, session: session}
  end
end
