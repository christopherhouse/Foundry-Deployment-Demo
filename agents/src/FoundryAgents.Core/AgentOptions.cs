namespace FoundryAgents.Core;

public enum AgentRole
{
    Triage,
    Market
}

public enum GatewayAuthMode
{
    EntraPlusKey,
    ApiKey
}

public sealed record AgentOptions(
    Uri GatewayEndpoint,
    string Profile,
    GatewayAuthMode AuthMode,
    string? TokenScope,
    string Model,
    string GatewayKey,
    string KeyHeader,
    string AgentLabel,
    bool UseLowReasoningEffort,
    int RetryMaxAttempts,
    TimeSpan RetryMaxDelay,
    TimeSpan RetryTotalBudget)
{
    public static AgentOptions Load(AgentRole role)
    {
        DotEnv.LoadNearest();

        return Environment.GetEnvironmentVariable("AGENT_BASE_URL") is { Length: > 0 }
            ? LoadProfile(role)
            : LoadLegacyFoundryProfile(role);
    }

    private static AgentOptions LoadProfile(AgentRole role)
    {
        GatewayAuthMode authMode = Required("AGENT_AUTH_MODE").ToLowerInvariant() switch
        {
            "entra-plus-key" => GatewayAuthMode.EntraPlusKey,
            "api-key" => GatewayAuthMode.ApiKey,
            _ => throw new InvalidOperationException(
                "Environment variable 'AGENT_AUTH_MODE' must be 'entra-plus-key' or 'api-key'.")
        };

        string keyVariable = role == AgentRole.Triage
            ? "AGENT_TRIAGE_GATEWAY_KEY"
            : "AGENT_MARKET_GATEWAY_KEY";
        string labelVariable = role == AgentRole.Triage
            ? "AGENT_TRIAGE_LABEL"
            : "AGENT_MARKET_LABEL";
        string defaultLabel = role == AgentRole.Triage ? "bronze" : "gold";

        return new AgentOptions(
            GatewayEndpoint: NormalizeEndpoint(Required("AGENT_BASE_URL"), "AGENT_BASE_URL"),
            Profile: Required("AGENT_PROFILE"),
            AuthMode: authMode,
            TokenScope: authMode == GatewayAuthMode.EntraPlusKey ? Required("AGENT_TOKEN_SCOPE") : null,
            Model: Required("AGENT_MODEL"),
            GatewayKey: Required(keyVariable),
            KeyHeader: HeaderName("AGENT_KEY_HEADER"),
            AgentLabel: Environment.GetEnvironmentVariable(labelVariable) is { Length: > 0 } label
                ? label
                : defaultLabel,
            UseLowReasoningEffort: ResolveLowReasoningEffort(authMode),
            RetryMaxAttempts: PositiveInt("AGENT_RETRY_MAX_ATTEMPTS", 5),
            RetryMaxDelay: TimeSpan.FromSeconds(PositiveInt("AGENT_RETRY_MAX_DELAY_SECONDS", 90)),
            RetryTotalBudget: TimeSpan.FromSeconds(PositiveInt("AGENT_RETRY_TOTAL_BUDGET_SECONDS", 180)));
    }

    private static AgentOptions LoadLegacyFoundryProfile(AgentRole role)
    {
        string subscriptionKeyVariable = role == AgentRole.Triage
            ? "FOUNDRY_BRONZE_SUBSCRIPTION_KEY"
            : "FOUNDRY_GOLD_SUBSCRIPTION_KEY";
        string label = role == AgentRole.Triage ? "bronze" : "gold";

        return new AgentOptions(
            GatewayEndpoint: NormalizeEndpoint(Required("FOUNDRY_APIM_BASE_URL"), "FOUNDRY_APIM_BASE_URL"),
            Profile: "foundry-apim",
            AuthMode: GatewayAuthMode.EntraPlusKey,
            TokenScope: Required("FOUNDRY_AGENT_SCOPE"),
            Model: Environment.GetEnvironmentVariable("FOUNDRY_MODEL") ?? "gpt-5-6-luna",
            GatewayKey: Required(subscriptionKeyVariable),
            KeyHeader: "Ocp-Apim-Subscription-Key",
            AgentLabel: label,
            UseLowReasoningEffort: true,
            RetryMaxAttempts: PositiveInt("FOUNDRY_RETRY_MAX_ATTEMPTS", 5),
            RetryMaxDelay: TimeSpan.FromSeconds(PositiveInt("FOUNDRY_RETRY_MAX_DELAY_SECONDS", 90)),
            RetryTotalBudget: TimeSpan.FromSeconds(PositiveInt("FOUNDRY_RETRY_TOTAL_BUDGET_SECONDS", 180)));
    }

    private static string Required(string name) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } value
            ? value
            : throw new InvalidOperationException(
                $"Environment variable '{name}' is required in the active agent profile.");

    private static string HeaderName(string name)
    {
        string value = Required(name);
        return value.All(character => char.IsAsciiLetterOrDigit(character) || character == '-')
            ? value
            : throw new InvalidOperationException(
                $"Environment variable '{name}' must contain only ASCII letters, digits, or hyphens.");
    }

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

    private static bool ResolveLowReasoningEffort(GatewayAuthMode authMode)
    {
        string? value = Environment.GetEnvironmentVariable("AGENT_REASONING_EFFORT");
        if (string.IsNullOrWhiteSpace(value))
        {
            return authMode == GatewayAuthMode.EntraPlusKey;
        }

        return value.ToLowerInvariant() switch
        {
            "low" => true,
            "none" => false,
            _ => throw new InvalidOperationException(
                "Environment variable 'AGENT_REASONING_EFFORT' must be 'low' or 'none'.")
        };
    }

    private static Uri NormalizeEndpoint(string value, string variableName)
    {
        string endpoint = value.TrimEnd('/') + "/";
        return Uri.TryCreate(endpoint, UriKind.Absolute, out Uri? uri) && uri.Scheme == Uri.UriSchemeHttps
            ? uri
            : throw new InvalidOperationException(
                $"Environment variable '{variableName}' must be an absolute HTTPS URL.");
    }
}
