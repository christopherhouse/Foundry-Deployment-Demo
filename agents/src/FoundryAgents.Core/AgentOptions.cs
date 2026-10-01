namespace FoundryAgents.Core;

public sealed record AgentOptions(
    Uri ApimEndpoint,
    string TokenScope,
    string Model,
    string SubscriptionKey,
    string Tier,
    int RetryMaxAttempts,
    TimeSpan RetryMaxDelay,
    TimeSpan RetryTotalBudget)
{
    public static AgentOptions Load(string tier, string subscriptionKeyVariable)
    {
        DotEnv.LoadNearest();

        return new AgentOptions(
            ApimEndpoint: NormalizeEndpoint(Required("FOUNDRY_APIM_BASE_URL")),
            TokenScope: Required("FOUNDRY_AGENT_SCOPE"),
            Model: Environment.GetEnvironmentVariable("FOUNDRY_MODEL") ?? "gpt-5-6-luna",
            SubscriptionKey: Required(subscriptionKeyVariable),
            Tier: tier,
            RetryMaxAttempts: PositiveInt("FOUNDRY_RETRY_MAX_ATTEMPTS", 5),
            RetryMaxDelay: TimeSpan.FromSeconds(PositiveInt("FOUNDRY_RETRY_MAX_DELAY_SECONDS", 90)),
            RetryTotalBudget: TimeSpan.FromSeconds(PositiveInt("FOUNDRY_RETRY_TOTAL_BUDGET_SECONDS", 180)));
    }

    private static string Required(string name) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } value
            ? value
            : throw new InvalidOperationException($"Environment variable '{name}' is required. Run scripts\\Initialize-AgentDemo.ps1 first.");

    private static int PositiveInt(string name, int defaultValue)
    {
        string? value = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue;
        }

        return int.TryParse(value, out int parsed) && parsed > 0
            ? parsed
            : throw new InvalidOperationException($"Environment variable '{name}' must be a positive integer.");
    }

    private static Uri NormalizeEndpoint(string value)
    {
        string endpoint = value.TrimEnd('/') + "/";
        return Uri.TryCreate(endpoint, UriKind.Absolute, out Uri? uri) && uri.Scheme == Uri.UriSchemeHttps
            ? uri
            : throw new InvalidOperationException("FOUNDRY_APIM_BASE_URL must be an absolute HTTPS URL ending at /openai/v1.");
    }
}
