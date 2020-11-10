defmodule ExBanking.Application do
  @moduledoc false
  import Supervisor.Spec

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: true

    children = [
      supervisor(ExBanking.UserSupervisor, []),
      ExBanking.CacheWorker,
      worker(ExBanking.CacheSupervisor, [
        ExBanking.CacheWorker,
        [
          :set,
          :public,
          :named_table,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ]
      ]),
      {Registry, keys: :unique, name: Registry.User}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
