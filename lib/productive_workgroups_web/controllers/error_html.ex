defmodule ProductiveWorkgroupsWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.
  """
  use ProductiveWorkgroupsWeb, :html

  embed_templates "error_html/*"

  # Default to 500.html.heex
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
