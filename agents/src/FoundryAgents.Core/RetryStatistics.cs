namespace FoundryAgents.Core;

public sealed class RetryStatistics
{
    private readonly object sync = new();
    private int retryCount;
    private int throttledCount;
    private int unavailableCount;
    private int forbiddenCount;
    private TimeSpan totalWait;

    public int RetryCount { get { lock (sync) { return retryCount; } } }
    public int ThrottledCount { get { lock (sync) { return throttledCount; } } }
    public int UnavailableCount { get { lock (sync) { return unavailableCount; } } }
    public int ForbiddenCount { get { lock (sync) { return forbiddenCount; } } }
    public TimeSpan TotalWait { get { lock (sync) { return totalWait; } } }

    internal bool CanWait(TimeSpan delay, TimeSpan budget)
    {
        lock (sync)
        {
            return totalWait + delay <= budget;
        }
    }

    internal void RecordRetry(int status, TimeSpan delay)
    {
        lock (sync)
        {
            retryCount++;
            totalWait += delay;
            if (status == 429) throttledCount++;
            if (status == 503) unavailableCount++;
        }
    }

    internal void RecordForbidden()
    {
        lock (sync)
        {
            forbiddenCount++;
        }
    }
}
