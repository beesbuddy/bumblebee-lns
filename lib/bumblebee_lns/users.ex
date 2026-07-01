defmodule BumblebeeLns.Users do
  @moduledoc """
  Reads and updates admin users stored in Mnesia.
  """

  @realm <<"bumblebee_lns">>
  @user_fields [:name, :pass_ha1, :scopes, :email, :send_alerts]

  def list_users do
    :user
    |> :mnesia.dirty_all_keys()
    |> Enum.flat_map(fn key ->
      case :mnesia.dirty_read(:user, key) do
        [record] -> [from_record(record)]
        [] -> []
      end
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def get_user(name) when is_binary(name) do
    name
    |> user_key()
    |> read_raw()
    |> case do
      {:ok, record} -> {:ok, from_record(record)}
      error -> error
    end
  end

  def create_user(params) when is_map(params) do
    with {:ok, attributes} <- validate(params),
         :ok <- ensure_missing(attributes.name) do
      write(user_record(attributes), &from_record/1)
    end
  end

  def update_user(name, params) when is_binary(name) and is_map(params) do
    with key <- user_key(name),
         {:ok, original} <- read_raw(key),
         {:ok, attributes} <- validate(Map.put(params, "name", name), from_record(original)) do
      attributes = Map.put(attributes, :name, key)
      write(user_record(attributes), &from_record/1)
    end
  end

  def delete_user(name) when is_binary(name) do
    key = user_key(name)

    with {:ok, record} <- read_raw(key) do
      :mnesia.dirty_delete(:user, key)
      {:ok, from_record(record)}
    end
  end

  def scope_options do
    :bumblebee_http_registry.get(:scopes)
    |> Enum.map(fn scope ->
      scope = to_string(scope)
      {scope, scope}
    end)
    |> Enum.sort_by(fn {label, _value} -> String.downcase(label) end)
  catch
    :exit, _reason -> [{"unlimited", "unlimited"}]
  end

  defp validate(params, original \\ nil) do
    name = params |> Map.get("name", "") |> to_string() |> String.trim()
    pass = params |> Map.get("pass", "") |> to_string() |> String.trim()
    scopes = normalize_scopes(Map.get(params, "scopes", []))

    errors =
      %{}
      |> add_error(name == "", :name, "Name is required")
      |> add_error(original == nil and pass == "", :pass, "Password is required")
      |> add_error(scopes == [], :scopes, "Scopes are required")

    if map_size(errors) == 0 do
      key = user_key(name)

      {:ok,
       %{
         name: key,
         pass_ha1: pass_ha1(key, pass, original),
         scopes: Enum.map(scopes, &to_binary/1),
         email: normalize_optional(Map.get(params, "email")),
         send_alerts: Map.get(params, "send_alerts") in [true, "true", "on", "1"]
       }}
    else
      {:error, errors}
    end
  end

  defp pass_ha1(_name, "", %{pass_ha1: pass_ha1}), do: to_binary(pass_ha1)

  defp pass_ha1(name, pass, _original) do
    :bumblebee_http_digest.ha1({to_binary(name), @realm, to_binary(pass)})
  end

  defp user_record(attributes) do
    {:user, attributes.name, attributes.pass_ha1, attributes.scopes, attributes.email,
     attributes.send_alerts}
  end

  defp write(record, mapper) do
    case :mnesia.transaction(fn -> :bumblebee_admin.write(record) end) do
      {:atomic, :ok} -> {:ok, mapper.(record)}
      {:aborted, reason} -> {:error, %{base: "Could not save user: #{inspect(reason)}"}}
    end
  end

  defp read_raw(key) do
    case :mnesia.dirty_read(:user, key) do
      [record] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  defp ensure_missing(name) do
    case :mnesia.dirty_read(:user, name) do
      [] -> :ok
      [_] -> {:error, %{name: "User already exists"}}
    end
  end

  defp from_record(record) do
    record
    |> tuple_map()
    |> Map.update!(:name, &to_string/1)
    |> Map.update!(:pass_ha1, &to_string/1)
    |> Map.update!(:scopes, &scopes_to_strings/1)
    |> Map.update!(:email, &optional_to_string/1)
    |> Map.update!(:send_alerts, &(&1 == true))
  end

  defp tuple_map(record) do
    values = record |> Tuple.to_list() |> tl()
    @user_fields |> Enum.zip(values) |> Map.new()
  end

  defp user_key(name), do: name |> to_string() |> String.trim() |> to_binary()

  defp normalize_scopes(scopes) do
    scopes
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp scopes_to_strings(:undefined), do: []
  defp scopes_to_strings(scopes), do: scopes |> List.wrap() |> Enum.map(&to_string/1)

  defp optional_to_string(:undefined), do: nil
  defp optional_to_string(nil), do: nil
  defp optional_to_string(value), do: to_string(value)

  defp normalize_optional(nil), do: nil
  defp normalize_optional(:undefined), do: nil

  defp normalize_optional(value),
    do: if((value = value |> to_string() |> String.trim()) == "", do: nil, else: value)

  defp to_binary(value) when is_binary(value), do: value
  defp to_binary(value), do: value |> to_string() |> :erlang.iolist_to_binary()

  defp add_error(errors, true, field, message), do: Map.put(errors, field, message)
  defp add_error(errors, false, _field, _message), do: errors
end
