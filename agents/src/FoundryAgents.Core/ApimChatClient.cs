using Azure.Identity;
using OpenAI;
using OpenAI.Chat;
using System.ClientModel.Primitives;

namespace FoundryAgents.Core;

public sealed class ApimChatClient
{
    public ApimChatClient(AgentOptions options, RetryStatistics retryStatistics)
    {
        OpenAIClientOptions clientOptions = new()
        {
            Endpoint = options.ApimEndpoint,
            RetryPolicy = new RetryAfterPolicy(options, retryStatistics)
        };
        clientOptions.AddPolicy(new SubscriptionKeyPolicy(options.SubscriptionKey), PipelinePosition.PerTry);

        Client = new ChatClient(
            options.Model,
            new BearerTokenPolicy(new DefaultAzureCredential(), options.TokenScope),
            clientOptions);
    }

    public ChatClient Client { get; }
}
