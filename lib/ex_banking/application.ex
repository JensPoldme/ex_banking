defmodule ExBanking.Application do
  @moduledoc false
  import Supervisor.Spec

  use Application

  def start(_type, _args) do
    children = [
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
      ])
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
