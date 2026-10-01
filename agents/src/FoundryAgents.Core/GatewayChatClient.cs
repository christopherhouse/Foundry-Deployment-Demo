using Azure.Identity;
using OpenAI;
using OpenAI.Chat;
using System.ClientModel;
using System.ClientModel.Primitives;

namespace FoundryAgents.Core;

public sealed class GatewayChatClient
{
    public GatewayChatClient(AgentOptions options, RetryStatistics retryStatistics)
    {
        OpenAIClientOptions clientOptions = new()
        {
            Endpoint = options.GatewayEndpoint,
            RetryPolicy = new RetryAfterPolicy(options, retryStatistics)
        };

        AuthenticationPolicy authenticationPolicy;
        if (options.AuthMode == GatewayAuthMode.EntraPlusKey)
        {
            authenticationPolicy = new BearerTokenPolicy(
                new DefaultAzureCredential(),
                options.TokenScope
                    ?? throw new InvalidOperationException("An Entra token scope is required for the active profile."));
            clientOptions.AddPolicy(
                new GatewayKeyPolicy(options.KeyHeader, options.GatewayKey),
                PipelinePosition.PerTry);
        }
        else
        {
            authenticationPolicy = ApiKeyAuthenticationPolicy.CreateHeaderApiKeyPolicy(
                new ApiKeyCredential(options.GatewayKey),
                options.KeyHeader,
                string.Empty);
        }

        Client = new ChatClient(options.Model, authenticationPolicy, clientOptions);
    }

    public ChatClient Client { get; }
}
