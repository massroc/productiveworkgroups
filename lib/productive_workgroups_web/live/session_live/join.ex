defmodule ProductiveWorkgroupsWeb.SessionLive.Join do
  @moduledoc """
  LiveView for joining an existing workshop session.
  """
  use ProductiveWorkgroupsWeb, :live_view

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Join Session",
       session_code: code
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-md w-full">
        <h1 class="text-2xl font-bold text-white mb-6 text-center">
          Join Workshop
        </h1>
        <p class="text-gray-400 text-center">
          Session code: <span class="font-mono text-white"><%= @session_code %></span>
        </p>
        <p class="text-gray-400 text-center mt-4">
          Join form coming soon...
        </p>
      </div>
    </div>
    """
  end
end
