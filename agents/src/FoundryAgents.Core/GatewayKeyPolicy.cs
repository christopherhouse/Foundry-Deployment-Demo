using System.ClientModel.Primitives;

namespace FoundryAgents.Core;

internal sealed class GatewayKeyPolicy(string headerName, string gatewayKey) : PipelinePolicy
{
    public override void Process(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
    {
        message.Request.Headers.Set(headerName, gatewayKey);
        ProcessNext(message, pipeline, currentIndex);
    }

    public override ValueTask ProcessAsync(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
    {
        message.Request.Headers.Set(headerName, gatewayKey);
        return ProcessNextAsync(message, pipeline, currentIndex);
    }
}
