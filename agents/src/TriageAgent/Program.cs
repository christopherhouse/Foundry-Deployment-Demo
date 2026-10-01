using Azure.Identity;
using FoundryAgents.Core;
using OpenAI.Chat;
using System.ClientModel;
using System.Text.Json;

AgentOptions options = AgentOptions.Load("bronze", "FOUNDRY_BRONZE_SUBSCRIPTION_KEY");
RetryStatistics retries = new();
ChatClient client = new ApimChatClient(options, retries).Client;
TokenReport report = new("Ticket Triage Agent", options.Tier, retries);

string dataPath = Path.Combine(AppContext.BaseDirectory, "Data", "tickets.json");
Ticket[] tickets = JsonSerializer.Deserialize<Ticket[]>(
    await File.ReadAllTextAsync(dataPath),
    new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
    ?? throw new InvalidOperationException("Ticket seed data is empty.");

Console.WriteLine($"Ticket Triage Agent: {tickets.Length} synthetic tickets, tier={options.Tier}, model={options.Model}");

try
{
    foreach (Ticket ticket in tickets)
    {
        ClientResult<ChatCompletion> result = await client.CompleteChatAsync(
            [
                new SystemChatMessage("You triage synthetic software support tickets. Return only compact JSON with string properties severity, category, and reply. Severity must be low, medium, high, or critical. Keep reply below 80 words."),
                new UserChatMessage(JsonSerializer.Serialize(ticket))
            ],
            new ChatCompletionOptions
            {
                MaxOutputTokenCount = 700,
                ReasoningEffortLevel = ChatReasoningEffortLevel.Low
            });

        report.Record(result.Value, result.GetRawResponse());
        string output = string.Concat(result.Value.Content.Select(part => part.Text));
        Console.WriteLine($"[{ticket.Id}] {output}");
    }

    return 0;
}
catch (AuthenticationFailedException exception)
{
    string detail = exception.Message.Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries)[0];
    Console.Error.WriteLine($"Ticket Triage Agent could not acquire an Entra token: {detail}");
    Console.Error.WriteLine("Refresh the Azure CLI sign-in for the configured tenant and agent scope, then retry.");
    return 2;
}
catch (ClientResultException exception)
{
    Console.Error.WriteLine($"Ticket Triage Agent stopped with HTTP {exception.Status}: {exception.Message}");
    return 1;
}
finally
{
    report.PrintSummary();
}

internal sealed record Ticket(string Id, string Subject, string Description);
