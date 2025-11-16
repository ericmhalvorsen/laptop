defmodule Vault.Commands.Install do
  @moduledoc """
  Install applications defined in config/apps.yaml.
  """

  alias Vault.UI.Progress

  def run(_args, opts) do
    manifest = load_manifest()

    Progress.puts([
      Progress.tag("\n📦 App Installation", :cyan),
      "\n\n",
      "Manifest: ",
      Progress.tag("config/apps.yaml", :yellow),
      "\n"
    ])

    install_brew(manifest, opts)
    install_local_pkgs(manifest, opts)
    install_local_dmgs(manifest, opts)
    handle_direct_downloads(manifest, opts)

    Progress.puts(["\n", Progress.tag("✓ Install complete", :green), "\n"])
  end

  defp load_manifest do
    path = Path.expand("config/apps.yaml", File.cwd!())

    case YamlElixir.read_from_file(path) do
      {:ok, doc} -> doc
      {:error, reason} ->
        Progress.puts([Progress.tag("✗ Failed to read config/apps.yaml: ", :red), inspect(reason)])
        System.halt(1)
    end
  end

  defp install_brew(%{"brew" => brew} = _manifest, opts) when is_map(brew) do
    dry = opts[:dry_run] == true

    brewfile = Path.expand("brew/Brewfile", File.cwd!())

    cond do
      File.exists?(brewfile) ->
        Progress.puts(["\n", Progress.tag("▶ Installing via Brewfile", :cyan), "\n"])
        brew_bundle(brewfile, dry)

      true ->
        formulas = Map.get(brew, "formulas", [])
        casks = Map.get(brew, "casks", [])

        if formulas != [] do
          Progress.puts(["\n", Progress.tag("▶ Installing brew formulas", :cyan), "\n"])
          Enum.each(formulas, fn f -> brew_install(["install", f], dry) end)
        end

        if casks != [] do
          Progress.puts(["\n", Progress.tag("▶ Installing brew casks", :cyan), "\n"])
          Enum.each(casks, fn c -> brew_install(["install", "--cask", c], dry) end)
        end
    end
  end

  defp install_brew(_manifest, _opts), do: :ok

  defp brew_install(args, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " brew ", Enum.join(args, " ")])
  end

  defp brew_install(args, false) do
    brew = System.find_executable("brew") || "brew"
    case System.cmd(brew, args, into: IO.stream(:stdio, :line)) do
      {_out, 0} -> :ok
      {out, code} -> Progress.puts([Progress.tag("✗ brew failed (#{code})\n", :red), out])
    end
  end

  defp brew_bundle(file, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " brew bundle --file=", file])
  end

  defp brew_bundle(file, false) do
    brew = System.find_executable("brew") || "brew"
    case System.cmd(brew, ["bundle", "--file=" <> file], into: IO.stream(:stdio, :line)) do
      {_out, 0} -> :ok
      {out, code} -> Progress.puts([Progress.tag("✗ brew bundle failed (#{code})\n", :red), out])
    end
  end

  defp install_local_pkgs(%{"local_pkg" => pkgs} = manifest, opts) when is_list(pkgs) do
    dry = opts[:dry_run] == true
    installers_dir = resolve_installers_dir(manifest, opts)
    private_dir = Path.join(installers_dir, "private")

    Progress.puts(["\n", Progress.tag("▶ Installing local .pkg installers", :cyan), "\n"])

    manual_actions =
      Enum.reduce(pkgs, [], fn item, acc ->
        name = item_name(item)
        requires_sudo = truthy(item["requires_sudo"])
        optional = truthy(item["optional"])

        pkg_pattern =
          item["pkg"]
          |> to_string()
          |> String.replace("{installers}", installers_dir)
          |> Path.expand()

        case Path.wildcard(pkg_pattern) do
          [path | _] ->
            case run_pkg(name, path, requires_sudo, dry) do
              :ok -> acc
              {:manual, msg} -> [msg | acc]
            end

          [] ->
            msg = "Missing installer for #{name} at #{pkg_pattern}"
            Progress.puts([Progress.tag("! ", :yellow), msg])
            [msg | acc]
        end
      end)
      |> Enum.reverse()

    unless dry do
      :ok = File.mkdir_p(private_dir)
    end

    if manual_actions != [] do
      Progress.puts(["\n", Progress.tag("Manual follow-up required:", :yellow)])

      Enum.each(manual_actions, fn msg ->
        Progress.puts(["  • ", msg])
      end)
    end

    Progress.puts([
      "\n",
      Progress.tag("ℹ Private installers directory:", :cyan),
      "\n  ",
      private_dir,
      "\n  ",
      Progress.tag("Tip:", :light_black),
      " open ",
      private_dir,
      "\n"
    ])
  end

  defp install_local_pkgs(_manifest, _opts), do: :ok

  defp run_pkg(name, path, requires_sudo, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " installer -pkg ", path, " -target /"])
    Progress.puts(["  ", Progress.tag("would install:", :light_black), " ", name])
    :ok
  end

  defp run_pkg(name, path, requires_sudo, false) do
    Progress.puts(["  Installing ", Progress.tag(name, :green), " from ", path])

    case System.cmd("installer", ["-pkg", path, "-target", "/"], into: IO.stream(:stdio, :line)) do
      {_out, 0} -> :ok
      {_out, code} ->
        msg =
          if requires_sudo do
            "#{name} installer exited with code #{code}. Re-run with sudo or install manually from #{path}."
          else
            "#{name} installer failed with code #{code}. Check installer at #{path}."
          end

        Progress.puts([Progress.tag("✗ installer failed (#{code})\n", :red)])
        {:manual, msg}
    end
  end

  defp handle_direct_downloads(%{"direct_download" => list}, opts) when is_list(list) do
    dry = opts[:dry_run] == true

    Enum.each(list, fn item ->
      id = item["id"] || item["name"]
      case item["id"] do
        "postgres-app" -> postgres_app_install(item, dry)
        _ ->
          Progress.puts([Progress.tag("! Skipping direct download installer for ", :yellow), to_string(id),
            Progress.tag(" (not yet implemented)", :light_black)])
      end
    end)
  end

  defp handle_direct_downloads(_manifest, _opts), do: :ok

  defp postgres_app_install(_item, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " Install Postgres.app from official site (manual step)"])
  end

  defp postgres_app_install(_item, false) do
    Progress.puts([Progress.tag("! Postgres.app automated install not implemented yet. Please install from https://postgresapp.com/", :yellow)])
  end

  defp item_name(item) do
    cond do
      is_map(item) and Map.has_key?(item, "name") -> item["name"]
      is_map(item) and Map.has_key?(item, :name) -> item[:name]
      true -> "unknown"
    end
  end

  defp resolve_installers_dir(manifest, _opts) do
    defaults = Map.get(manifest, "defaults", %{})
    raw = Map.get(defaults, "installers_dir", "~/Installers")
    expand_home(raw)
  end

  defp expand_home(path) when is_binary(path) do
    case String.starts_with?(path, "~") do
      true -> Path.join(System.user_home!(), String.trim_leading(path, "~/"))
      false -> path
    end
  end

  # -- Local DMG handling --
  defp install_local_dmgs(%{"local_dmg" => dmgs} = manifest, opts) when is_list(dmgs) do
    dry = opts[:dry_run] == true
    installers_dir = resolve_installers_dir(manifest, opts)

    Owl.IO.puts(["\n", Owl.Data.tag("▶ Installing from local .dmg images", :cyan), "\n"])

    Enum.each(dmgs, fn item ->
      name = item_name(item)
      optional = truthy(item["optional"])

      dmg_pattern =
        item["dmg"]
        |> to_string()
        |> String.replace("{installers}", installers_dir)
        |> Path.expand()

      candidates = Path.wildcard(dmg_pattern)

      case candidates do
        [path | _] ->
          with {:ok, mount} <- attach_dmg(path, dry) do
            try do
              app_name = Map.get(item, "app_name")
              handle_dmg_contents(mount, app_name, dry)
            after
              detach_dmg(mount, dry)
            end
          else
            {:error, reason} -> Progress.puts([Progress.tag("! Failed to attach DMG: ", :yellow), to_string(reason)])
          end
        [] ->
          msg = "Missing DMG for #{name} at #{dmg_pattern}"
          if optional, do: Progress.puts([Progress.tag("! ", :yellow), msg]), else: Progress.puts([Progress.tag("! ", :yellow), msg])
      end
    end)
  end

  defp install_local_dmgs(_manifest, _opts), do: :ok

  defp attach_dmg(path, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " hdiutil attach -nobrowse ", path])
    {:ok, "/Volumes/DRYRUN"}
  end

  defp attach_dmg(path, false) do
    case System.cmd("hdiutil", ["attach", path, "-nobrowse"], stderr_to_stdout: true) do
      {out, 0} ->
        mount =
          out
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(fn line ->
            case Regex.run(~r{(/Volumes/[^\s]+)$}, line) do
              [_, mnt] -> mnt
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> List.last()

        if mount, do: {:ok, mount}, else: {:error, :mountpoint_not_found}
      {out, code} -> {:error, "hdiutil attach failed (#{code}): #{out}"}
    end
  end

  defp detach_dmg(_mount, true), do: :ok
  defp detach_dmg(mount, false) do
    _ = System.cmd("hdiutil", ["detach", mount], stderr_to_stdout: true)
    :ok
  end

  defp handle_dmg_contents(mount, nil, true) do
    Progress.puts(["  ", Progress.tag("dry-run:", :light_black), " would open ", mount, " for manual installation."])
  end

  defp handle_dmg_contents(mount, nil, false) do
    Progress.puts([Progress.tag("! No app_name specified for ", :yellow), mount, ". Opening volume for manual install..."])
    _ = System.cmd("open", [mount])
    :ok
  end

  defp handle_dmg_contents(mount, app_name, true) when is_binary(app_name) do
    Owl.IO.puts(["  ", Owl.Data.tag("dry-run:", :light_black), " cp -R ", Path.join(mount, app_name), " /Applications/"])
  end

  defp handle_dmg_contents(mount, app_name, false) when is_binary(app_name) do
    src = Path.join(mount, app_name)
    case File.exists?(src) do
      true ->
        {out, code} = System.cmd("cp", ["-R", src, "/Applications/"], stderr_to_stdout: true)
        if code == 0, do: :ok, else: Progress.puts([Progress.tag("✗ Failed to copy app (#{code})\n", :red), out])
      false ->
        Progress.puts([Progress.tag("! App not found in mounted volume: ", :yellow), src, ". Opening volume..."])
        _ = System.cmd("open", [mount])
        :ok
    end
  end

  defp truthy(val) do
    case val do
      true -> true
      "true" -> true
      1 -> true
      "1" -> true
      _ -> false
    end
  end
end
