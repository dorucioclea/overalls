defmodule Lilly.Ingress.SocketCustody do
  @moduledoc "Exclusive ownership and bounded stale-socket recovery for the local connector."
  import Bitwise
  alias Lilly.Host.{Lock, PrivateFiles}

  # @cc [owner:ghuntley,label:recovery] ingress-socket-exclusive-recovery
  # Recovery MUST hold the same persistent OS lock before claiming or removing a
  # socket. Only a service-owned Unix socket under a previously recorded exact
  # path may be removed. Initial claims MUST require an absent path. The private
  # claim is durable before bind, so death between claim and bind is recoverable.
  # Lock inodes MUST never be replaced, and unknown files MUST remain untouched.
  @spec acquire(binary()) :: {:ok, Lilly.Host.Lease.t()} | {:error, :connector_unavailable}
  def acquire(path) do
    directory = path <> ".owner"

    with {:ok, lock} <- acquire_lock(directory, 10) do
      case prepare(directory, path) do
        :ok ->
          {:ok, lock}

        _ ->
          Lock.release(lock)
          {:error, :connector_unavailable}
      end
    else
      _ -> {:error, :connector_unavailable}
    end
  end

  defp acquire_lock(directory, retries) do
    case Lock.acquire(directory) do
      {:error, :host_already_owned} when retries > 0 ->
        Process.sleep(20)
        acquire_lock(directory, retries - 1)

      result ->
        result
    end
  end

  defp prepare(directory, path) do
    claim = Path.join(directory, "socket-path")

    case File.lstat(claim) do
      {:error, :enoent} ->
        with {:error, :enoent} <- Lilly.Host.Privilege.lstat(path),
             do: PrivateFiles.write(directory, "socket-path", path)

      {:ok, _} ->
        with {:ok, ^path} <- PrivateFiles.read_secret(claim), do: recover(path)

      _ ->
        :error
    end
  end

  defp recover(path) do
    {:ok, %{uid: uid}} = Lilly.Host.Privilege.stat("/proc/self")

    case Lilly.Host.Privilege.lstat(path) do
      {:error, :enoent} -> :ok
      {:ok, %{uid: ^uid, mode: mode}} when band(mode, 0o170000) == 0o140000 -> File.rm(path)
      _ -> :error
    end
  end
end
