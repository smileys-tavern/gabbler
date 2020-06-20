defmodule Gabbler.User.Query do
  @moduledoc """
  The main querying interface for a User Account. Handles the relationship between cache and
  persistant store.
  """
  @behaviour GabblerData.Behaviour.QueryUser

  alias Gabbler.Cache
  alias Gabbler.Accounts.User
  alias GabblerData.Query.User, as: QueryUser

  @cache_default_ttl 86400 # 1 DAY


  def get(%User{name: name}), do: get_by_name(name)

  @impl true
  def get(id), do: QueryUser.get(id)

  @impl true
  def get_by_name(name) do
    case Cache.get("USER_#{name}") do
      nil ->
        QueryUser.get_by_name(name)
        |> Cache.set_if("USER_#{name}", ttl: @cache_default_ttl)
        |> user_found?()
      user ->
        {:cachehit, user}
    end
  end

  @impl true
  def create(changeset), do: QueryUser.create(changeset)

  # PRIVATE FUNCTIONS
  ###################
  defp user_found?(nil), do: {:error, :user_not_found}
  defp user_found?(user), do: {:ok, user}
end