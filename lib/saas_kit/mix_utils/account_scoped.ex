defmodule SaasKit.MixUtils.AccountScoped do
  def account_scoped_question(args) do
    Mix.shell().info """

    ===============================================================
    === Account Scoped ============================================
    ===============================================================
    The resource you are generating could belong directly under an account.
    This means that all queries will be tweaked so they are account scoped. You should
    use this when you need account specific data.
    """
    accountscope = if Mix.shell().yes?("#{IO.ANSI.green}Belong to an account?#{IO.ANSI.reset}"), do: true, else: false

    case accountscope do
      true -> Enum.reject(args, &(String.match?(&1, ~r/account_id/))) ++ ["account_id:references:accounts"]
      _ -> args
    end
  end
end
