defmodule SaasKit.ApiAdapter.SetupQuestions do
  def get_questions() do
    [
      %{
        "uuid_for_ids" => "Use UUID:s as primary keys for tables",
      },
    ]
  end
end
