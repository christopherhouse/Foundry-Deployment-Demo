using Azure.Identity;
using FoundryAgents.Core;
using OpenAI.Chat;
using System.ClientModel;
using System.Text.Json;
using System.Text.Json.Serialization;

AgentOptions options = AgentOptions.Load(AgentRole.Market);
RetryStatistics retries = new();
ChatClient client = new GatewayChatClient(options, retries).Client;
TokenReport report = new("Market Brief Analyst", options, retries);

string dataPath = Path.Combine(AppContext.BaseDirectory, "Data", "signals.json");
Signal[] signals = JsonSerializer.Deserialize<Signal[]>(await File.ReadAllTextAsync(dataPath))
    ?? throw new InvalidOperationException("Market signal seed data is empty.");
string evidence = JsonSerializer.Serialize(signals);

Console.WriteLine(
    $"Market Brief Analyst: {signals.Length} synthetic signals, profile={options.Profile}, " +
    $"label={options.AgentLabel}, auth={options.AuthMode}, model={options.Model}");

try
{
    string outline = await Complete(
        "Create a detailed outline for an executive market brief using only the synthetic evidence. Identify opportunities, risks, contradictions, and decisions. Do not invent facts.",
        evidence,
        2500);

    string brief = await Complete(
        "Write a polished 900-1200 word market brief from the supplied outline and evidence. Label all data as synthetic. Include sections for executive context, demand, adoption, retention, risk, economics, and recommended actions.",
        $"EVIDENCE:\n{evidence}\n\nOUTLINE:\n{outline}",
        5000);

    string summary = await Complete(
        "Produce a concise executive summary with five bullets and a final recommendation. Use only the supplied synthetic brief.",
        brief,
        1800);

    Console.WriteLine();
    Console.WriteLine("=== Executive summary ===");
    Console.WriteLine(summary);
    return 0;
}
catch (AuthenticationFailedException exception)
{
    string detail = exception.Message.Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries)[0];
    Console.Error.WriteLine($"Market Brief Analyst could not acquire an Entra token: {detail}");
    Console.Error.WriteLine("Refresh the Azure CLI sign-in for the configured tenant and agent scope, then retry.");
    return 2;
}
catch (ClientResultException exception)
{
    Console.Error.WriteLine($"Market Brief Analyst stopped with HTTP {exception.Status}: {exception.Message}");
    return 1;
}
finally
{
    report.PrintSummary();
}

async Task<string> Complete(string instruction, string content, int maxOutputTokens)
{
    ClientResult<ChatCompletion> result = await client.CompleteChatAsync(
        [new SystemChatMessage(instruction), new UserChatMessage(content)],
        new ChatCompletionOptions
        {
            MaxOutputTokenCount = maxOutputTokens,
            ReasoningEffortLevel = ChatReasoningEffortLevel.Low
        });

    report.Record(result.Value, result.GetRawResponse());
    return string.Concat(result.Value.Content.Select(part => part.Text));
}

internal sealed record Signal(
    [property: JsonPropertyName("category")] string Category,
    [property: JsonPropertyName("signal")] string Description);
