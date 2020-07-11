defmodule Gabbler.User.Chat do
  @moduledoc """
  Contains functionality related to chat from the user perspective
  """
  @chat_timer 5000 # One message globally per 5 seconds

  def start_chat_timer() do
    self()
    |> Process.send_after(:chat_timer, @chat_timer)
    :ok
  end
end
