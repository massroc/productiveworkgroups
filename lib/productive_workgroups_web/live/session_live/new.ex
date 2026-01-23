defmodule ProductiveWorkgroupsWeb.SessionLive.New do
  @moduledoc """
  LiveView for creating a new workshop session.
  """
  use ProductiveWorkgroupsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "New Session")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-md w-full">
        <h1 class="text-2xl font-bold text-white mb-6 text-center">
          Create New Workshop
        </h1>
        <p class="text-gray-400 text-center">
          Session creation form coming soon...
        </p>
      </div>
    </div>
    """
  end
end
