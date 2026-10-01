using OpenAI.Chat;
using System.ClientModel.Primitives;
using System.Diagnostics;

namespace FoundryAgents.Core;

public sealed class TokenReport(string agentName, string tier, RetryStatistics retryStatistics)
{
    private readonly Stopwatch stopwatch = Stopwatch.StartNew();
    private int calls;
    private long inputTokens;
    private long outputTokens;
    private long totalTokens;

    public void Record(ChatCompletion completion, PipelineResponse response)
    {
        calls++;
        inputTokens += completion.Usage.InputTokenCount;
        outputTokens += completion.Usage.OutputTokenCount;
        totalTokens += completion.Usage.TotalTokenCount;

        Console.WriteLine(
            $"[{tier}] call {calls}: input={completion.Usage.InputTokenCount}, output={completion.Usage.OutputTokenCount}, total={completion.Usage.TotalTokenCount}, " +
            $"apim-tier={Header(response, "X-Foundry-Tier")}, apim-consumed={Header(response, "X-Foundry-Tokens-Consumed")}, remaining-minute={Header(response, "X-Foundry-Remaining-Tokens")}, remaining-day={Header(response, "X-Foundry-Remaining-Quota-Tokens")}");
    }

    public void PrintSummary()
    {
        stopwatch.Stop();
        Console.WriteLine();
        Console.WriteLine($"=== {agentName} summary ({tier}) ===");
        Console.WriteLine($"Calls: {calls}");
        Console.WriteLine($"Tokens: input={inputTokens}, output={outputTokens}, total={totalTokens}");
        Console.WriteLine($"Retries: {retryStatistics.RetryCount} (429={retryStatistics.ThrottledCount}, 503={retryStatistics.UnavailableCount})");
        Console.WriteLine($"Retry wait: {retryStatistics.TotalWait.TotalSeconds:0.0}s");
        Console.WriteLine($"Quota failures: {retryStatistics.QuotaExceededCount}");
        Console.WriteLine($"Elapsed: {stopwatch.Elapsed}");
    }

    private static string Header(PipelineResponse response, string name) =>
        response.Headers.TryGetValue(name, out string? value) ? value ?? "n/a" : "n/a";
}
