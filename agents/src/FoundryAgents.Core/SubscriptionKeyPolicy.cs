using System.ClientModel.Primitives;

namespace FoundryAgents.Core;

internal sealed class SubscriptionKeyPolicy(string subscriptionKey) : PipelinePolicy
{
    public override void Process(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
    {
        message.Request.Headers.Set("Ocp-Apim-Subscription-Key", subscriptionKey);
        ProcessNext(message, pipeline, currentIndex);
    }

    public override ValueTask ProcessAsync(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
    {
        message.Request.Headers.Set("Ocp-Apim-Subscription-Key", subscriptionKey);
        return ProcessNextAsync(message, pipeline, currentIndex);
    }
}
