using System.ClientModel.Primitives;
using System.Globalization;

namespace FoundryAgents.Core;

public sealed class RetryAfterPolicy : ClientRetryPolicy
{
    private readonly string tier;
    private readonly int maxAttempts;
    private readonly TimeSpan maxDelay;
    private readonly TimeSpan totalBudget;
    private readonly RetryStatistics statistics;

    public RetryAfterPolicy(AgentOptions options, RetryStatistics statistics)
        : base(Math.Max(0, options.RetryMaxAttempts - 1))
    {
        tier = options.Tier;
        maxAttempts = options.RetryMaxAttempts;
        maxDelay = options.RetryMaxDelay;
        totalBudget = options.RetryTotalBudget;
        this.statistics = statistics;
    }

    protected override bool ShouldRetry(PipelineMessage message, Exception? exception)
    {
        if (exception is not null)
        {
            return false;
        }

        int status = message.Response?.Status ?? 0;
        if (status == 403)
        {
            statistics.RecordQuotaExceeded();
            Console.Error.WriteLine($"[{tier}] Daily token quota exhausted (HTTP 403); this response is not retried.");
            return false;
        }

        return (status == 429 || status == 503)
            && statistics.TotalWait < totalBudget
            && base.ShouldRetry(message, exception);
    }

    protected override ValueTask<bool> ShouldRetryAsync(PipelineMessage message, Exception? exception) =>
        ValueTask.FromResult(ShouldRetry(message, exception));

    protected override TimeSpan GetNextDelay(PipelineMessage message, int tryCount)
    {
        int status = message.Response?.Status ?? 0;
        bool usedRetryAfter = TryGetRetryAfter(message.Response, out TimeSpan retryAfter);
        TimeSpan delay = usedRetryAfter
            ? retryAfter
            : TimeSpan.FromSeconds(Math.Pow(2, Math.Clamp(tryCount - 1, 0, 10)));

        delay += TimeSpan.FromMilliseconds(Random.Shared.Next(100, 751));
        if (delay > maxDelay)
        {
            delay = maxDelay;
        }

        if (!statistics.CanWait(delay, totalBudget))
        {
            Console.Error.WriteLine($"[{tier}] Retry wait budget of {totalBudget.TotalSeconds:0}s is exhausted; no additional delay will be applied.");
            return TimeSpan.Zero;
        }

        statistics.RecordRetry(status, delay);
        string delaySource = usedRetryAfter ? "per Retry-After" : "with exponential backoff";
        Console.WriteLine($"[{tier}] HTTP {status}; waiting {delay.TotalSeconds:0.0}s {delaySource} before attempt {Math.Min(tryCount + 1, maxAttempts)}/{maxAttempts}.");
        return delay;
    }

    private static bool TryGetRetryAfter(PipelineResponse? response, out TimeSpan delay)
    {
        delay = default;
        if (response is null || !response.Headers.TryGetValue("Retry-After", out string? value))
        {
            return false;
        }

        if (int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out int seconds) && seconds >= 0)
        {
            delay = TimeSpan.FromSeconds(seconds);
            return true;
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset retryAt))
        {
            delay = retryAt - DateTimeOffset.UtcNow;
            if (delay < TimeSpan.Zero)
            {
                delay = TimeSpan.Zero;
            }
            return true;
        }

        return false;
    }
}
